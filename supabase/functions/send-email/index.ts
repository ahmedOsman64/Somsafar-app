import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import nodemailer from "npm:nodemailer@6.9.10"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Content-Type': 'application/json; charset=utf-8',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { booking_id, recipient, pdf_base64, subject, html_body } = await req.json()

    if (!booking_id || !recipient || !pdf_base64 || !subject || !html_body) {
      return new Response(
        JSON.stringify({ success: false, message: 'Missing required parameters: booking_id, recipient, pdf_base64, subject, html_body' }),
        { status: 400, headers: corsHeaders }
      )
    }

    // SMTP Configuration
    const senderEmail = Deno.env.get('EMAIL_SENDER') ?? 'somsafarbooking@gmail.com'
    const senderAppPassword = Deno.env.get('EMAIL_APP_PASSWORD') ?? 'inxawydkjhevqlbu'
    const senderName = 'SomSafar Booking System'

    console.log(`[Email Service] Attempting to send receipt email to: ${recipient} for Booking: ${booking_id}`)

    const transporter = nodemailer.createTransport({
      host: 'smtp.gmail.com',
      port: 465,
      secure: true,
      auth: {
        user: senderEmail,
        pass: senderAppPassword,
      },
    })

    const mailOptions = {
      from: `"${senderName}" <${senderEmail}>`,
      to: recipient,
      subject: subject,
      html: html_body,
      attachments: [
        {
          filename: `SomSafar_Booking_${booking_id.substring(0, 8).toUpperCase()}.pdf`,
          content: pdf_base64,
          encoding: 'base64',
        },
      ],
    }

    const info = await transporter.sendMail(mailOptions)
    console.log('[Email Service] Email sent successfully:', info.messageId)

    return new Response(
      JSON.stringify({ success: true, message: 'Email sent successfully', messageId: info.messageId }),
      { status: 200, headers: corsHeaders }
    )
  } catch (error) {
    console.error('[Email Service] Error sending email:', error)
    const message = error instanceof Error ? error.message : 'Unknown error'
    return new Response(
      JSON.stringify({ success: false, message: 'Failed to send email.', error: message }),
      { status: 500, headers: corsHeaders }
    )
  }
})
