import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-webhook-signature, x-webhook-timestamp, x-webhook-event-id',
}

async function verifySignature(secret: string, signature: string, timestamp: string, eventId: string, body: string): Promise<boolean> {
  const encoder = new TextEncoder()
  const keyData = encoder.encode(secret)
  const message = `${timestamp}.${eventId}.${body}`
  const data = encoder.encode(message)

  const key = await crypto.subtle.importKey(
    "raw",
    keyData,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify", "sign"]
  )

  const computedSignature = await crypto.subtle.sign("HMAC", key, data)
  const computedHex = Array.from(new Uint8Array(computedSignature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("")

  // Timing-safe comparison
  if (computedHex.length !== signature.length) return false
  let result = 0
  for (let i = 0; i < computedHex.length; i++) {
    result |= computedHex.charCodeAt(i) ^ signature.charCodeAt(i)
  }
  return result === 0
}


Deno.serve(async (req) => {
  // 1. Authenticate (WaafiPay might use a secret key or fixed IP)
  // For WaafiPay HPP, they usually send a POST request with parameters.
  // Note: Depending on WaafiPay version, validation might differ.
  
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '' // Use service role for webhooks
    )

    // In Deno, we can only read the body once. Use text() to support signature verification.
    const rawBody = await req.text()
    let body
    try {
      body = JSON.parse(rawBody)
    } catch (_e) {
      return new Response(JSON.stringify({ success: false, message: 'Invalid JSON body' }), { status: 400 })
    }
    console.log('Webhook received:', body)

    // 2. Signature Verification
    const signature = req.headers.get('X-Webhook-Signature')
    const timestamp = req.headers.get('X-Webhook-Timestamp')
    const eventId = req.headers.get('X-Webhook-Event-Id')
    const webhookSecret = Deno.env.get('WAAFIPAY_WEBHOOK_SECRET')


    if (!webhookSecret) {
      console.error('WAAFIPAY_WEBHOOK_SECRET is not configured')
      return new Response(JSON.stringify({ success: false, message: 'Server configuration error' }), { status: 500 })
    }

    if (!signature || !timestamp || !eventId) {
      console.error('Missing signature headers')
      return new Response(JSON.stringify({ success: false, message: 'Missing signature headers' }), { status: 401 })
    }

    const isValid = await verifySignature(webhookSecret, signature, timestamp, eventId, rawBody)
    if (!isValid) {
      console.error('Invalid signature')
      return new Response(JSON.stringify({ success: false, message: 'Invalid signature' }), { status: 401 })
    }
    
    // Replay Protection: Check timestamp (e.g., within 5 minutes)
    const now = Math.floor(Date.now() / 1000)
    const msgTime = parseInt(timestamp)
    if (isNaN(msgTime) || Math.abs(now - msgTime) > 300) {
      console.error('Webhook timestamp expired or invalid:', timestamp)
      return new Response(JSON.stringify({ success: false, message: 'Timestamp expired' }), { status: 401 })
    }


    // 3. Process the event
    const { requestId, responseCode, params } = body
    const { referenceId, state, transactionId } = params || {}

    // Track Webhook Event (Internal Replay Protection)
    const { error: eventError } = await supabaseClient
      .from('webhook_events')
      .insert({
        event_id: requestId || eventId, // Fallback to header eventId
        payload: body,
        processed: true
      })

    if (eventError && eventError.code === '23505') {
       console.log('Event already processed:', requestId || eventId)
       return new Response(JSON.stringify({ success: true, message: 'Already processed' }), { status: 200 })
    }

    if (responseCode === "2001" && state === "APPROVED") {
      // Update transaction status
      const { data: transaction } = await supabaseClient
        .from('payment_transactions')
        .update({ transaction_status: 'SUCCESSFUL', waafipay_response: body })
        .eq('reference_id', referenceId)
        .select()
        .single()

      if (transaction) {
        // Update booking status
        await supabaseClient
          .from('bookings')
          .update({ payment_status: 'paid', status: 'pending', transaction_id: transactionId })
          .eq('id', transaction.booking_id)
      }
    }


    return new Response(JSON.stringify({ success: true }), { 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200 
    })

  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error'
    console.error('Webhook error:', error)
    return new Response(JSON.stringify({ success: false, error: message }), { status: 500 })
  }
})
