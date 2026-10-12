import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const WAAFIPAY_API_URL = Deno.env.get('WAAFIPAY_BASE_URL') ?? "https://api.waafipay.net/asm"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, idempotency-key',
  'Content-Type': 'application/json; charset=utf-8',
  'Cache-Control': 'no-store, max-age=0',
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
}

/**
 * Robustly extract client IP address
 */
function getClientIP(req: Request): string {
  const forwarded = req.headers.get('x-forwarded-for')
  if (forwarded) {
    return forwarded.split(',')[0].trim()
  }
  return req.headers.get('x-real-ip') || 'unknown'
}

/**
 * Sanitizes WaafiPay response to exclude sensitive PII/Metadata
 */
function sanitizeWaafiResponse(result: WaafiResponse) {
  if (!result) return null
  return {
    responseCode: result.responseCode,
    responseMsg: result.responseMsg,
    errorCode: result.errorCode,
    state: result.params?.state,
    transactionId: result.params?.transactionId,
    requestId: result.requestId
  }
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

/**
 * Maps WaafiPay/Hormuud error messages to human-readable messages in the given locale.
 * Supported locales: 'so' (Somali, default), 'en' (English), 'ar' (Arabic/Saudi).
 */
function mapWaafiError(responseMsg: string, locale = 'so'): string {
  const msgs: Record<string, Record<string, string>> = {
    fallback: {
      so: 'Lacag bixintu way fashilantay. Fadlan isku day hadhow.',
      en: 'Payment failed. Please try again later.',
      ar: 'فشلت عملية الدفع. يرجى المحاولة لاحقاً.',
    },
    balance: {
      so: 'Haraagaagu kuguma filna. Fadlan ku shubo kaddibna isku day mar kale.',
      en: 'Insufficient balance. Please top up and try again.',
      ar: 'رصيدك غير كافٍ. يرجى إعادة الشحن والمحاولة مجدداً.',
    },
    subscriber: {
      so: 'Lambarka taleefanku ma shaqaynayo ama uma qalmo lacag bixinta.',
      en: 'The phone number is inactive or not eligible for payment.',
      ar: 'رقم الهاتف غير نشط أو غير مؤهل للدفع.',
    },
    pin: {
      so: 'PIN-ka aad gelisay waa khalad ama lama aqoonsan. Fadlan isku day mar kale.',
      en: 'The PIN you entered is incorrect or unrecognized. Please try again.',
      ar: 'الرقم السري الذي أدخلته غير صحيح. يرجى المحاولة مجدداً.',
    },
    cancelled: {
      so: 'Lacag bixinta adiga ayaa joojiyay (Cancelled). Fadlan dib u bilow haddii aad rabto.',
      en: 'Payment was cancelled by you. Please restart if you wish to pay.',
      ar: 'تم إلغاء الدفع من قِبلك. يرجى البدء من جديد إذا أردت الدفع.',
    },
    limit: {
      so: 'Waxaad gaartay xadka lacag bixinta ee maalinlaha ah (Daily Limit).',
      en: 'You have reached your daily payment limit.',
      ar: 'لقد وصلت إلى حد الدفع اليومي.',
    },
    rejected: {
      so: 'Lacag bixinta waa la diiday. Fadlan hubi xadkaaga ama isku day lambar kale.',
      en: 'Payment was declined. Please check your limit or try a different number.',
      ar: 'تم رفض الدفع. يرجى مراجعة رصيدك أو تجربة رقم آخر.',
    },
    timeout: {
      so: 'Muddada macaamilku waa dhammaatay (Timeout). Fadlan isku day mar kale.',
      en: 'The transaction timed out. Please try again.',
      ar: 'انتهت مهلة المعاملة. يرجى المحاولة مجدداً.',
    },
  }

  const lang = (locale === 'en' || locale === 'ar') ? locale : 'so'

  if (!responseMsg) return msgs.fallback[lang]

  // Fix typo in Somali message returned by WaafiPay
  let mappedMsg = responseMsg
  if (mappedMsg.includes('u direyso')) {
    mappedMsg = mappedMsg.replace('u direyso', 'ka direyso')
  } else if (mappedMsg.includes('u direeso')) {
    mappedMsg = mappedMsg.replace('u direeso', 'ka direeso')
  }

  const msg = mappedMsg.toLowerCase()

  if (msg.includes('balance') || msg.includes('enough') || msg.includes('haraaga')) {
    return msgs.balance[lang]
  }
  if (msg.includes('subscriber') || msg.includes('inactive') || msg.includes('not active')) {
    return msgs.subscriber[lang]
  }
  if (msg.includes('pin') || msg.includes('credential') || msg.includes('secret')) {
    return msgs.pin[lang]
  }
  if (msg.includes('cancel') || msg.includes('user_cancel') || msg.includes('rejected by user')) {
    return msgs.cancelled[lang]
  }
  if (msg.includes('limit') || msg.includes('daily') || msg.includes('threshold')) {
    return msgs.limit[lang]
  }
  if (msg.includes('rejected') || msg.includes('declined')) {
    return msgs.rejected[lang]
  }
  if (msg.includes('timeout') || msg.includes('time out')) {
    return msgs.timeout[lang]
  }

  return mappedMsg
}

interface WaafiResponse {
  responseCode: string;
  responseMsg: string;
  errorCode: string;
  params?: {
    state?: string;
    transactionId?: string;
    transactionid?: string;
    transactionState?: string;
    paymentUrl?: string;
  };
  requestId?: string;
  [key: string]: unknown;
}

/**
 * Executes WaafiPay API call with timeout and retries
 */
async function callWaafiPay(payload: Record<string, unknown>, retries = 2): Promise<WaafiResponse> {
  const timeoutMs = 90000 // Increased to 90s for Live USSD PIN entry
  
  for (let attempt = 0; attempt <= retries; attempt++) {
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), timeoutMs)
    
    try {
      const response = await fetch(WAAFIPAY_API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
        signal: controller.signal
      })
      
      clearTimeout(timer)
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      
      return await response.json()
    } catch (err: unknown) {
      const error = err as Record<string, unknown>
      clearTimeout(timer)
      const isLastAttempt = attempt === retries
      const isNetworkError = error?.name !== 'AbortError' && !(err instanceof SyntaxError)
      
      console.warn(`WaafiPay API attempt ${attempt + 1} failed:`, error?.message)
      
      if (isLastAttempt || !isNetworkError) {
        throw error
      }
      
      // Wait before retry (exponential backoff: 1s, 2s)
      await new Promise(resolve => setTimeout(resolve, 1000 * Math.pow(2, attempt)))
    }
  }
  
  throw new Error('Unexpected end of payment process')
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const clientIP = getClientIP(req)
  const idempotencyKey = req.headers.get('idempotency-key')

  try {
    // 1. Auth and Client Setup
    const authHeader = req.headers.get('Authorization')
    
    // User client (Respects RLS) - used for identity and ownership checks
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: authHeader ? { Authorization: authHeader } : {},
        },
      }
    )

    // Admin client (Bypasses RLS) - used for internal logging and status updates
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const token = authHeader?.replace('Bearer ', '');
    const { data: { user }, error: userError } = await userClient.auth.getUser(token)

    if (userError || !user) {
      return new Response(
        JSON.stringify({ success: false, message: 'Unauthorized' }),
        { headers: corsHeaders, status: 401 }
      )
    }

    // JSON Body validation
    let body;
    try {
      body = await req.json()
    } catch (_e) {
      return new Response(
        JSON.stringify({ success: false, message: 'Invalid JSON body' }),
        { headers: corsHeaders, status: 400 }
      )
    }

    const { booking_id, account_no, payment_method = "MWALLET_ACCOUNT", idempotency_key: _idempotency_key, locale = 'so' } = body
    const lang = (locale === 'en' || locale === 'ar') ? locale : 'so'

    const i18n: Record<string, Record<string, string>> = {
      already_paid: {
        so: 'Lacag bixinta boos-qabsashadan horay ayaa loo habeeyay.',
        en: 'This booking has already been paid.',
        ar: 'تم الدفع لهذا الحجز مسبقاً.',
      },
      api_error: {
        so: 'Isgaarsiinta nidaamka lacag bixinta way fashilantay. Fadlan isku day mar kale.',
        en: 'Could not reach the payment system. Please try again.',
        ar: 'تعذّر الاتصال بنظام الدفع. يرجى المحاولة مجدداً.',
      },
      booking_sync_warn: {
        so: 'Lacagta waa la helay, balse nidaamka ayaan weli la jaan-qaadin. Fadlan la xiriir caawinta macaamiisha.',
        en: 'Payment received, but the booking is not yet updated. Please contact support.',
        ar: 'تم استلام الدفع، لكن الحجز لم يُحدَّث بعد. يرجى التواصل مع الدعم.',
      },
      success: {
        so: 'Lacag bixinta waa lagu guuleystay',
        en: 'Payment completed successfully.',
        ar: 'تمت عملية الدفع بنجاح.',
      },
      global_error: {
        so: 'Khalad farsamo ayaa dhacay',
        en: 'A technical error occurred.',
        ar: 'حدث خطأ فني.',
      },
    }

    if (!booking_id || (payment_method === "MWALLET_ACCOUNT" && !account_no)) {
      return new Response(
        JSON.stringify({ success: false, message: 'Missing required fields: booking_id is mandatory, and account_no is required for Mobile Money' }),
        { headers: corsHeaders, status: 400 }
      )
    }

    // 2. Rate Limiting (Enforced to prevent payment brute-forcing and flooding)
    const { data: isAllowed, error: rateLimitError } = await adminClient
      .rpc('check_payment_rate_limit', { p_user_id: user.id })

    if (rateLimitError) {
      console.warn('[Payment] Rate limit check error:', rateLimitError)
    } else if (isAllowed === false) {
      return new Response(
        JSON.stringify({ success: false, message: 'Isku dayitaan aad u badan. Fadlan sug daqiiqad kaddibna isku day mar kale.' }),
        { headers: corsHeaders, status: 429 }
      )
    }

    const invoiceId = `INV-${Date.now()}-${Math.floor(Math.random() * 1000)}`
    const referenceId = `REF-${crypto.randomUUID()}`

    // Record attempt with references (Using Admin Client to guarantee logging)
    const { error: attemptLogError } = await adminClient.from('payment_attempts').insert({
      user_id: user.id,
      booking_id: booking_id,
      ip_address: clientIP,
      status: 'started',
      metadata: { idempotencyKey, referenceId, invoiceId }
    })

    if (attemptLogError) {
      console.error('[Payment] Failed to log attempt:', attemptLogError)
      // We continue as recording the attempt shouldn't block the actual payment
    }

    // 3. Race Condition & Status Check
    // Check for existing SUCCESSFUL transactions first (Atomic constraint check)
    const { data: existingSuccess } = await userClient
      .from('payment_transactions')
      .select('id')
      .eq('booking_id', booking_id)
      .eq('transaction_status', 'SUCCESSFUL')
      .maybeSingle()

    if (existingSuccess) {
      return new Response(
        JSON.stringify({ success: false, message: i18n.already_paid[lang] }),
        { headers: corsHeaders, status: 400 }
      )
    }

    // Fetch and Validate Booking
    const { data: booking, error: bookingError } = await userClient
      .from('bookings')
      .select('*')
      .eq('id', booking_id)
      .single()

    if (bookingError || !booking) {
      return new Response(
        JSON.stringify({ success: false, message: 'Booking not found' }),
        { headers: corsHeaders, status: 404 }
      )
    }

    if (booking.traveler_id !== user.id) {
       return new Response(
        JSON.stringify({ success: false, message: 'Unauthorized: Booking ownership mismatch' }),
        { headers: corsHeaders, status: 403 }
      )
    }

    if (booking.payment_status === 'paid' || booking.status !== 'pending') {
      return new Response(
        JSON.stringify({ success: false, message: 'Booking is already paid or not in pending status' }),
        { headers: corsHeaders, status: 400 }
      )
    }

    // 4. Prepare WaafiPay Request
    const merchantUid = Deno.env.get('WAAFIPAY_MERCHANT_UID')
    const apiUserId = Deno.env.get('WAAFIPAY_API_USER_ID')
    const apiKey = Deno.env.get('WAAFIPAY_API_KEY')
    
    if (!merchantUid || !apiUserId || !apiKey) {
      console.error('[Payment] Missing WaafiPay credentials in environment variables.')
    }

    let sanitizedAccount = ""
    if (account_no) {
      sanitizedAccount = account_no.replace(/\+/g, '').replace(/^0+/, '')
      if (!sanitizedAccount.startsWith('252')) {
        sanitizedAccount = '252' + sanitizedAccount
      }
    }


    const waafiPayRequest = {
      schemaVersion: "1.0",
      requestId: crypto.randomUUID(),
      timestamp: getWaafiTimestamp(),
      channelName: "WEB",
      serviceName: "API_PURCHASE",
      serviceParams: {
        merchantUid,
        apiUserId,
        apiKey,
        paymentMethod: payment_method,
        payerInfo: payment_method === "MWALLET_ACCOUNT" ? { accountNo: sanitizedAccount } : undefined,
        transactionInfo: {
          amount: parseFloat(booking.total_price).toFixed(2),
          currency: "USD",
          description: `Somsafar Booking: ${booking.service_title}`,
          referenceId: referenceId,
          invoiceId: invoiceId
        }
      }
    }
    
    console.log(`[Payment] Initializing request for Booking: ${booking_id}`)
    console.log(`[Payment] Environment: ${WAAFIPAY_API_URL.includes('sandbox') ? 'SANDBOX' : 'PROD'}`)
    console.log(`[Payment] Payload:`, JSON.stringify({ 
      ...waafiPayRequest, 
      serviceParams: { 
        ...waafiPayRequest.serviceParams, 
        apiKey: apiKey ? (apiKey.substring(0, 8) + '***') : 'MISSING',
        merchantUid: merchantUid || 'MISSING',
        apiUserId: apiUserId || 'MISSING'
      } 
    }, null, 2))

    // 5. Execute Payment with Retry Logic or Mock Sandbox Success
    let result;
    const isExplicitSandboxEnv = (Deno.env.get('ENVIRONMENT') ?? Deno.env.get('DENO_ENV') ?? '').toLowerCase() === 'sandbox';
    const isSandboxUrl = WAAFIPAY_API_URL.includes('sandbox') || WAAFIPAY_API_URL.includes('api-test') || WAAFIPAY_API_URL.includes('test');
    const isOfficialTestNumber = sanitizedAccount === '252615000000' || sanitizedAccount === '252613000000' || sanitizedAccount === '252617000000';
    // Mocking only triggers if environment is explicitly configured as sandbox AND using a sandbox URL
    const shouldMockSuccess = isExplicitSandboxEnv && isSandboxUrl && !isOfficialTestNumber;

    if (shouldMockSuccess) {
      console.log(`[Payment] Sandbox Mode: Mocking successful payment for unregistered number: ${sanitizedAccount}`);
      result = {
        responseCode: "2001",
        responseMsg: "Transaction approved successfully (Mocked)",
        errorCode: "0",
        params: {
          state: "APPROVED",
          transactionId: `MOCK-TX-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
          transactionState: "APPROVED"
        },
        requestId: waafiPayRequest.requestId
      };
    } else {
      try {
        result = await callWaafiPay(waafiPayRequest)
        console.log(`[Payment] WaafiPay Raw Response:`, JSON.stringify(result, null, 2))
      } catch (apiError) {
        console.error('WaafiPay final failure:', apiError)
        return new Response(
          JSON.stringify({ 
            success: false, 
            message: i18n.api_error[lang]
          }),
          { headers: corsHeaders, status: 504 }
        )
      }
    }

    const isSuccessful = 
      result.responseCode === "2001" && 
      result.errorCode === "0" && 
      (result.params?.state === "APPROVED" || 
       result.params?.transactionState === "APPROVED" ||
       (payment_method === "CREDIT_CARD" && result.params?.paymentUrl))

    const waafiTransactionId = result.params?.transactionId || result.params?.transactionid
    console.log(`[Payment] Result: ${isSuccessful ? 'SUCCESS' : 'FAILED'}, State: ${result.params?.state}, Waafi ID: ${waafiTransactionId}`)

    // 6. Record Transaction & Audit (Using Admin Client)
    const sanitizedResult = sanitizeWaafiResponse(result)
    
    const { error: transError } = await adminClient
      .from('payment_transactions')
      .insert({
        booking_id: booking_id,
        user_id: user.id,
        invoice_id: invoiceId,
        reference_id: referenceId,
        amount: booking.total_price,
        payment_method: payment_method || 'Mobile Money',
        transaction_status: isSuccessful ? 'SUCCESSFUL' : 'FAILED',
        waafipay_transaction_id: waafiTransactionId,
        waafipay_response: sanitizedResult
      })

    if (transError) {
      console.error('Failed to log transaction:', transError)
      // We don't return here if payment was successful, we must try to update booking
    }

    await adminClient.from('audit_logs').insert({
      user_id: user.id,
      action_performed: isSuccessful ? 'PAYMENT_SUCCESS' : 'PAYMENT_FAILED',
      ip_address: clientIP,
      device_info: req.headers.get('user-agent'),
      metadata: {
        booking_id,
        invoiceId,
        amount: booking.total_price,
        status: isSuccessful ? 'SUCCESS' : 'FAILED',
        errorCode: result.errorCode
      }
    })

    if (isSuccessful) {
      // If it's a credit card, we don't update booking yet, just return the URL
      if (payment_method === "CREDIT_CARD" && result.params?.paymentUrl) {
        return new Response(
          JSON.stringify({
            success: true,
            status: 'pending_redirect',
            payment_url: result.params.paymentUrl,
            message: 'Redirecting to payment gate...',
            data: { invoice_id: invoiceId, reference_id: referenceId }
          }),
          { headers: corsHeaders, status: 200 }
        )
      }

      // Final Sync: Update Booking (Using Admin Client to bypass RLS)
      const { error: updateError } = await adminClient
        .from('bookings')
        .update({
          payment_status: 'paid',
          status: 'pending',
          transaction_id: waafiTransactionId || referenceId
        })
        .eq('id', booking_id)

      if (updateError) {
        console.error('CRITICAL: Payment successful but booking update failed:', updateError)
        // This is a dangerous state, but we return success to the user since we have their money
        return new Response(
          JSON.stringify({
            success: true,
            warning: 'Booking update pending',
            message: i18n.booking_sync_warn[lang],
            data: { invoice_id: invoiceId, reference_id: referenceId }
          }),
          { headers: corsHeaders, status: 200 }
        )
      }

      return new Response(
        JSON.stringify({
          success: true,
          message: i18n.success[lang],
          data: { invoice_id: invoiceId, reference_id: referenceId }
        }),
        { headers: corsHeaders, status: 200 }
      )
    } else {
      return new Response(
        JSON.stringify({
          success: false,
          message: mapWaafiError(result.responseMsg, lang),
          data: sanitizedResult
        }),
        { headers: corsHeaders, status: 400 }
      )
    }

  } catch (error) {
    const message = error instanceof Error ? error.message : 'Unknown error'
    console.error('Global payment processing error:', error)
    return new Response(
      JSON.stringify({ 
        success: false, 
        message: 'A technical error occurred.',
        error: message
      }),
      { headers: corsHeaders, status: 500 }
    )
  }
})

