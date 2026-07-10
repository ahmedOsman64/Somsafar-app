import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const WAAFIPAY_API_URL = Deno.env.get('WAAFIPAY_BASE_URL') ?? "https://api-test.waafipay.net/asm"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // 1. Identify "Stuck" (Pending) Transactions
    // We look for transactions that have been 'PENDING' for more than 10 minutes
    const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000).toISOString()
    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString()
    
    const { data: transactionsToReconcile, error: fetchError } = await supabaseClient
      .from('payment_transactions')
      .select('*')
      .in('transaction_status', ['PENDING', 'FAILED'])
      .lt('created_at', tenMinutesAgo)
      .gt('created_at', twentyFourHoursAgo)

    // 1b. Identify "Stale" Attempts (Started but no transaction record)
    const { data: staleAttempts, error: attemptError } = await supabaseClient
      .from('payment_attempts')
      .select('*')
      .eq('status', 'started')
      .lt('attempted_at', tenMinutesAgo)
      .gt('attempted_at', twentyFourHoursAgo)

    if (fetchError || attemptError) throw (fetchError || attemptError)

    // Combine them into a unified list of things to verify
    const workList = [
      ...(transactionsToReconcile || []).map(t => ({ id: t.id, type: 'TRANSACTION', ref: t.reference_id, booking_id: t.booking_id, data: t })),
      ...(staleAttempts || []).map(a => ({ id: a.id, type: 'ATTEMPT', ref: a.metadata?.referenceId, booking_id: a.booking_id, data: a }))
    ]

    const summary = {
      total_checked: workList.length,
      updated_to_success: 0,
      updated_to_failed: 0,
      still_pending: 0,
      errors: [] as string[]
    }

    const discrepancies = []

    // 2. Query WaafiPay for each
    for (const item of workList) {
      if (!item.ref) {
        summary.errors.push(`Missing reference for ${item.type} ${item.id}`)
        continue
      }
      try {
        // Prepare Query Request (Placeholder serviceName: API_PREAUTHORIZE_INFO or similar)
        // Usually, gateways have a 'get-status' or 'query' endpoint.
        const queryRequest = {
          schemaVersion: "1.0",
          requestId: crypto.randomUUID(),
          timestamp: new Date().toISOString(),
          channelName: "WEB",
          serviceName: "API_PREAUTHORIZE_INFO", // WaafiPay standard for status inquiry
          serviceParams: {
            merchantUid: Deno.env.get('WAAFIPAY_MERCHANT_UID'),
            apiUserId: Deno.env.get('WAAFIPAY_API_USER_ID'),
            apiKey: Deno.env.get('WAAFIPAY_API_KEY'),
            transactionInfo: {
              referenceId: item.ref
            }
          }
        }

        // Mock/Assumption: Call WaafiPay and wait for status
        // const response = await fetch(WAAFIPAY_API_URL, { ... })
        // const result = await response.json()
        
        // 2. Mock/Query WaafiPay for status
        const response = await fetch(WAAFIPAY_API_URL, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(queryRequest)
        })
        const result = await response.json()
        
        // Logic: If result shows APPROVED, we sync the DB
        const isRemoteSuccess = result.responseCode === "2001" && 
                                (result.params?.state === "APPROVED" || result.params?.transactionState === "APPROVED")

        if (isRemoteSuccess) {
          // If it was just an attempt record, we need to create the transaction record now
          if (item.type === 'ATTEMPT') {
             const waafiTransactionId = result.params?.transactionId || result.params?.transactionid
             
             await supabaseClient.from('payment_transactions').insert({
               booking_id: item.booking_id,
               user_id: item.data.user_id,
               invoice_id: item.data.metadata?.invoiceId,
               reference_id: item.ref,
               amount: 0, // We should fetch amount from booking if needed
               transaction_status: 'SUCCESSFUL',
               waafipay_transaction_id: waafiTransactionId,
               waafipay_response: { reconciliation_from_attempt: result }
             })
          } else {
             // Update existing transaction
             await supabaseClient
               .from('payment_transactions')
               .update({ 
                  transaction_status: 'SUCCESSFUL', 
                  waafipay_transaction_id: result.params?.transactionId || result.params?.transactionid,
                  waafipay_response: { ...item.data.waafipay_response, reconciliation: result } 
               })
               .eq('id', item.id)
          }

          // Update booking
          const waafiTransactionId = result.params?.transactionId || result.params?.transactionid
          await supabaseClient
            .from('bookings')
            .update({ 
              payment_status: 'paid', 
              status: 'pending',
              transaction_id: waafiTransactionId || item.ref
            })
            .eq('id', item.booking_id)

          summary.updated_to_success++
          discrepancies.push({ ref: item.ref, issue: 'Paid but marked Pending/Missing', resolved: true })
        } else if (result.params?.state === 'FAILED' || result.params?.state === 'CANCELLED') {
          if (item.type === 'TRANSACTION') {
            await supabaseClient
              .from('payment_transactions')
              .update({ transaction_status: 'FAILED' })
              .eq('id', item.id)
          }
          
          summary.updated_to_failed++
        } else {
          summary.still_pending++
        }

        // Close attempt if it was a stale attempt
        if (item.type === 'ATTEMPT') {
          await supabaseClient
            .from('payment_attempts')
            .update({ status: 'completed' })
            .eq('id', item.id)
        }

      } catch (err) {
        const message = err instanceof Error ? err.message : 'Unknown error'
        summary.errors.push(`Error checking REF ${item.ref}: ${message}`)
      }

    }

    // 3. Save Reconciliation Report
    const { error: reportError } = await supabaseClient
      .from('reconciliation_reports')
      .insert({
        summary,
        discrepancies,
        status: discrepancies.length > 0 ? 'DISCREPANCY_FOUND' : 'MATCHED'
      })

    if (reportError) throw reportError

    return new Response(JSON.stringify({ success: true, summary }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    })

  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error'
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500 })
  }

})
