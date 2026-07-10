import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const WAAFIPAY_API_URL = Deno.env.get('WAAFIPAY_BASE_URL') ?? "https://sandbox.waafipay.com/asm"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function getWaafiTimestamp() {
  const now = new Date()
  const year = now.getFullYear()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const day = String(now.getDate()).padStart(2, '0')
  const hours = String(now.getHours()).padStart(2, '0')
  const minutes = String(now.getMinutes()).padStart(2, '0')
  const seconds = String(now.getSeconds()).padStart(2, '0')
  const ms = String(now.getMilliseconds()).padStart(3, '0')
  return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}.${ms}`
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: authHeader ? { Authorization: authHeader } : {},
        },
      }
    )

    const token = authHeader?.replace('Bearer ', '')
    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser(token)

    if (userError || !user) {
      return new Response(JSON.stringify({ success: false, message: 'Unauthorized' }), { status: 401, headers: corsHeaders })
    }

    const { reference_id } = await req.json()

    // 1. Fetch transaction
    const { data: transaction, error: transError } = await supabaseClient
      .from('payment_transactions')
      .select('*, bookings(*)')
      .eq('reference_id', reference_id)
      .single()

    if (transError || !transaction) {
      return new Response(JSON.stringify({ success: false, message: 'Transaction not found' }), { status: 404, headers: corsHeaders })
    }

    // Security: Only owner or admin can verify
    if (transaction.user_id !== user.id) {
        const { data: isAdmin } = await supabaseClient.rpc('is_admin')
        if (!isAdmin) {
            return new Response(JSON.stringify({ success: false, message: 'Forbidden' }), { status: 403, headers: corsHeaders })
        }
    }

    // 2. WaafiPay Inquiry Request
    const merchantUid = Deno.env.get('WAAFIPAY_MERCHANT_UID')
    const storeId = Deno.env.get('WAAFIPAY_STORE_ID')
    const hppKey = Deno.env.get('WAAFIPAY_HPP_KEY')

    // Note: Documentation recommends HPP_GETTRANINFO for status checks
    const inquiryRequest = {
      schemaVersion: "1.0",
      requestId: crypto.randomUUID(),
      timestamp: getWaafiTimestamp(),
      channelName: "WEB",
      serviceName: "HPP_GETTRANINFO",
      serviceParams: {
        merchantUid,
        storeId,
        hppKey,
        transactionId: transaction.waafipay_response?.params?.transactionId || transaction.id,
        referenceId: reference_id
      }
    }

    const transactionId = transaction.waafipay_response?.params?.transactionId || transaction.id;
    const isMockTransaction = typeof transactionId === 'string' && transactionId.startsWith('MOCK-TX-');

    let result;
    if (isMockTransaction) {
      console.log(`[Verify] Sandbox Mode: Verifying mocked transaction: ${transactionId}`);
      result = {
        responseCode: "2001",
        responseMsg: "Transaction approved successfully (Mocked)",
        errorCode: "0",
        params: {
          state: "APPROVED",
          transactionId: transactionId,
          transactionState: "APPROVED"
        },
        requestId: inquiryRequest.requestId
      };
    } else {
      const response = await fetch(WAAFIPAY_API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(inquiryRequest)
      })
      result = await response.json()
    }

    // 3. Handle result
    const remoteStatus = 
      result.responseCode === "2001" && 
      result.errorCode === "0" && 
      (result.params?.state === "APPROVED" || result.params?.transactionState === "APPROVED")
        ? "SUCCESSFUL" 
        : "FAILED"
    
    if (remoteStatus !== transaction.transaction_status) {
        // Sync local DB if there's a mismatch
        await supabaseClient
          .from('payment_transactions')
          .update({ transaction_status: remoteStatus, waafipay_response: result })
          .eq('id', transaction.id)

        if (remoteStatus === 'SUCCESSFUL') {
            await supabaseClient
                .from('bookings')
                .update({ payment_status: 'paid', status: 'pending' })
                .eq('id', transaction.booking_id)
        }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Transaction is ${remoteStatus}`,
        data: {
            status: remoteStatus,
            waafipay_details: result
        }
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error'
    return new Response(JSON.stringify({ success: false, message }), { status: 500, headers: corsHeaders })
  }
})
