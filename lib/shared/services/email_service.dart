import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/booking_model.dart';

/// Handles automatic email delivery of booking confirmation receipts.
/// Uses Gmail SMTP (App Password) to send PDF attachments.
class EmailService {
  // ── SMTP Configuration (loaded from .env) ──────────────────────────────────
  static String get _senderEmail =>
      dotenv.env['EMAIL_SENDER'] ?? 'somsafarbooking@gmail.com';
  static String get _senderAppPassword =>
      dotenv.env['EMAIL_APP_PASSWORD'] ?? '';
  static const String _senderName = 'SomSafar Booking System';

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Called automatically when a provider ACCEPTS (confirms) a booking.
  /// Generates a PDF receipt and emails it to the traveler.
  static Future<void> sendBookingConfirmationEmail(Booking booking) async {
    if (booking.contactEmail.trim().isEmpty) {
      debugPrint('EmailService: No email on booking ${booking.id}, skipping.');
      return;
    }

    try {
      // 1. Generate the PDF bytes
      final pdfBytes = await _generateReceiptPdf(booking);

      // 2. Build the email message
      final smtpServer = gmail(_senderEmail, _senderAppPassword);

      final message = Message()
        ..from = Address(_senderEmail, _senderName)
        ..recipients.add(booking.contactEmail.trim())
        ..subject = '✅ Booking Confirmed – ${booking.serviceTitle}'
        ..html = _buildEmailBody(booking)
        ..attachments = [
          StreamAttachment(
            Stream.fromIterable([pdfBytes]),
            'application/pdf',
            fileName:
                'SomSafar_Booking_${booking.id.substring(0, 8).toUpperCase()}.pdf',
          ),
        ];

      // 3. Send
      final sendReport = await send(message, smtpServer);
      debugPrint(
          'EmailService: Confirmation email sent → ${sendReport.toString()}');
    } catch (e) {
      // Non-fatal: log but don't crash the booking flow
      debugPrint('EmailService: Failed to send email – $e');
    }
  }

  // ── PDF Generation ──────────────────────────────────────────────────────────

  static Future<Uint8List> _generateReceiptPdf(Booking booking) async {
    final pdf = pw.Document();

    final metadata = booking.metadata;
    final isTour =
        metadata['serviceType']?.toString().toLowerCase() == 'tour' ||
            booking.serviceTitle.toLowerCase().contains('tour');
    final isVehicle =
        metadata['serviceType']?.toString().toLowerCase() == 'vehicle' ||
            booking.serviceTitle.toLowerCase().contains('car') ||
            booking.serviceTitle.toLowerCase().contains('rent');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // ── Header ───────────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('SomSafar',
                      style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(0xFF0A3D62),
                      )),
                  pw.Text('Travel with Confidence',
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('BOOKING CONFIRMED',
                      style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(0xFF27AE60))),
                  pw.Text(
                      'Ref: #${booking.id.substring(0, 8).toUpperCase()}',
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Divider(thickness: 1, color: PdfColors.grey300),
          pw.SizedBox(height: 16),

          // ── Service Info ─────────────────────────────────────────────────
          _section('SERVICE INFORMATION', [
            _row('Service', booking.serviceTitle),
            _row('Status', '✅ CONFIRMED'),
            _row('Booking Date',
                DateFormat('MMM dd, yyyy HH:mm').format(booking.date)),
          ]),
          pw.SizedBox(height: 16),

          // ── Traveler Details ─────────────────────────────────────────────
          _section('TRAVELER DETAILS', [
            _row('Name', booking.travelerName),
            _row('Phone', booking.contactPhone.isNotEmpty
                ? booking.contactPhone
                : 'N/A'),
            _row('Email', booking.contactEmail),
          ]),
          pw.SizedBox(height: 16),

          // ── Booking Details ──────────────────────────────────────────────
          _section('BOOKING DETAILS', [
            if (isTour) ...[
              _row(
                  booking.checkIn == booking.checkOut
                      ? 'Tour Date'
                      : 'Start Date',
                  DateFormat('MMM dd, yyyy').format(booking.checkIn)),
              if (booking.checkIn != booking.checkOut)
                _row('End Date',
                    DateFormat('MMM dd, yyyy').format(booking.checkOut)),
            ] else if (isVehicle) ...[
              _row('Pickup',
                  DateFormat('MMM dd, yyyy').format(booking.checkIn)),
              _row('Return',
                  DateFormat('MMM dd, yyyy').format(booking.checkOut)),
              if (metadata['pickupLocation'] != null)
                _row('Pickup Location', metadata['pickupLocation'].toString()),
            ] else ...[
              _row('Check-in',
                  DateFormat('MMM dd, yyyy').format(booking.checkIn)),
              _row('Check-out',
                  DateFormat('MMM dd, yyyy').format(booking.checkOut)),
            ],
            _row('Guests', '${booking.guests} Guests'),
            if (booking.rooms > 0) _row('Rooms/Units', '${booking.rooms}'),
            if (booking.specialRequests != null &&
                booking.specialRequests!.isNotEmpty)
              _row('Special Requests', booking.specialRequests!),
          ]),
          pw.SizedBox(height: 16),

          // ── Payment ──────────────────────────────────────────────────────
          _section('PAYMENT INFORMATION', [
            _row('Subtotal',
                '\$${(booking.totalPrice - booking.taxes).toStringAsFixed(2)}'),
            _row('Tax', '\$${booking.taxes.toStringAsFixed(2)}'),
            _row('Total Price', '\$${booking.totalPrice.toStringAsFixed(2)}'),
            _row('Method', _formatMethod(booking.paymentMethod)),
            _row('Payment Status', booking.paymentStatus.name.toUpperCase()),
          ]),

          pw.SizedBox(height: 40),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text(
              'Thank you for choosing SomSafar! Questions? somsafarbooking@gmail.com',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ── Email HTML Body ─────────────────────────────────────────────────────────

  static String _buildEmailBody(Booking booking) {
    final checkIn = DateFormat('MMM dd, yyyy').format(booking.checkIn);
    final checkOut = DateFormat('MMM dd, yyyy').format(booking.checkOut);
    final total = '\$${booking.totalPrice.toStringAsFixed(2)}';
    final refId = booking.id.substring(0, 8).toUpperCase();

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8"/>
  <style>
    body { font-family: Arial, sans-serif; background: #f4f6f8; margin: 0; padding: 20px; }
    .card { background: #fff; border-radius: 12px; max-width: 560px; margin: 0 auto; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.08); }
    .header { background: linear-gradient(135deg, #0D3B66, #1B62A4); padding: 30px; text-align: center; }
    .header h1 { color: #fff; margin: 0; font-size: 26px; letter-spacing: 1px; }
    .header p { color: rgba(255,255,255,0.75); margin: 4px 0 0; font-size: 13px; }
    .badge { background: #27AE60; color: #fff; display: inline-block; padding: 6px 20px; border-radius: 20px; font-weight: bold; font-size: 14px; margin: 20px 0 0; }
    .body { padding: 28px 32px; }
    .greeting { font-size: 17px; color: #1a1a2e; font-weight: bold; margin-bottom: 8px; }
    .sub { color: #555; font-size: 14px; margin-bottom: 24px; }
    .section-title { font-size: 11px; font-weight: bold; color: #0D3B66; letter-spacing: 1px; text-transform: uppercase; margin-bottom: 10px; border-bottom: 1px solid #e9ecef; padding-bottom: 6px; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
    td { padding: 7px 4px; font-size: 13px; color: #444; }
    td:first-child { color: #888; width: 140px; }
    td:last-child { font-weight: 600; color: #222; }
    .total-row td { font-size: 15px; font-weight: bold; color: #0D3B66; border-top: 1px solid #e9ecef; padding-top: 10px; }
    .footer { background: #f8f9fa; padding: 18px 32px; text-align: center; font-size: 12px; color: #aaa; border-top: 1px solid #e9ecef; }
    .footer a { color: #0D3B66; text-decoration: none; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h1>🌍 SomSafar</h1>
      <p>Travel with Confidence</p>
      <div class="badge">✅ Booking Confirmed</div>
    </div>
    <div class="body">
      <p class="greeting">Hello, ${booking.travelerName}!</p>
      <p class="sub">Great news – your booking has been <strong>confirmed</strong> by the provider. Please find your receipt PDF attached to this email.</p>

      <div class="section-title">📋 Booking Summary</div>
      <table>
        <tr><td>Reference</td><td>#$refId</td></tr>
        <tr><td>Service</td><td>${booking.serviceTitle}</td></tr>
        <tr><td>Check-in</td><td>$checkIn</td></tr>
        <tr><td>Check-out</td><td>$checkOut</td></tr>
        <tr><td>Guests</td><td>${booking.guests}</td></tr>
        <tr><td>Rooms/Units</td><td>${booking.rooms}</td></tr>
      </table>

      <div class="section-title">💳 Payment</div>
      <table>
        <tr><td>Method</td><td>${_formatMethod(booking.paymentMethod)}</td></tr>
        <tr><td>Status</td><td>${booking.paymentStatus.name.toUpperCase()}</td></tr>
        <tr class="total-row"><td>Total</td><td>$total</td></tr>
      </table>

      <p style="font-size:13px; color:#555;">The <strong>full receipt PDF</strong> is attached. Please keep it for your records.</p>
    </div>
    <div class="footer">
      Questions? Contact us at <a href="mailto:somsafarbooking@gmail.com">somsafarbooking@gmail.com</a><br/>
      © 2026 SomSafar · All rights reserved
    </div>
  </div>
</body>
</html>
''';
  }

  // ── PDF Helpers ─────────────────────────────────────────────────────────────

  static pw.Widget _section(String title, List<pw.Widget> children) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF0A3D62))),
        pw.SizedBox(height: 6),
        ...children,
      ],
    );
  }

  static pw.Widget _row(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
              width: 120,
              child: pw.Text('$label:',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey700))),
          pw.Expanded(
              child: pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold))),
        ],
      ),
    );
  }

  static String _formatMethod(String? method) {
    if (method == null) return 'N/A';
    final m = method.toLowerCase();
    if (m.contains('card')) return 'Credit/Debit Card';
    if (m.contains('mobile')) return 'Mobile Money';
    if (m.contains('bank')) return 'Bank Transfer';
    if (m.contains('paylater')) return 'Pay at Arrival';
    return method.replaceAll('PaymentMethod.', '');
  }
}
