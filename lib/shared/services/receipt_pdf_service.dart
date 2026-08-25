import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/booking_model.dart';

class ReceiptPdfService {
  static Future<void> generateAndShare(Booking booking) async {
    final pdf = pw.Document();
    
    // Load Unicode fonts including Arabic
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontArabic = await PdfGoogleFonts.amiriRegular();

    final metadata = booking.metadata;
    final isTour = metadata['serviceType']?.toString().toLowerCase() == 'tour' ||
        booking.serviceTitle.toLowerCase().contains('tour');
    final isVehicle = metadata['serviceType']?.toString().toLowerCase() == 'vehicle' ||
        booking.serviceTitle.toLowerCase().contains('car') ||
        booking.serviceTitle.toLowerCase().contains('rent');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
        ),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    booking.serviceTitle.isNotEmpty
                        ? booking.serviceTitle
                        : 'SomSafar Partner',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFF0A3D62),
                    ),
                  ),
                  pw.Text(
                    'Official Booking Receipt · Verified Service',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'BOOKING RECEIPT',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Ref: #${booking.id.toUpperCase()}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 30),
          pw.Divider(thickness: 1, color: PdfColors.grey300),
          pw.SizedBox(height: 20),

          // Service Info
          _buildPdfSection('SERVICE INFORMATION', [
            _buildPdfRow('Service', booking.serviceTitle),
            _buildPdfRow('Status', booking.statusLabel),
            _buildPdfRow(
              'Booking Date',
              DateFormat('MMM dd, yyyy HH:mm').format(booking.date),
            ),
          ]),

          pw.SizedBox(height: 20),

          // Traveler Details
          _buildSectionWithTitle('TRAVELER DETAILS', [
            _buildPdfRow('Name', booking.travelerName),
            _buildPdfRow('Phone', booking.contactPhone),
            _buildPdfRow('Email', booking.contactEmail),
          ]),

          pw.SizedBox(height: 20),

          // Booking Details
          _buildSectionWithTitle('BOOKING DETAILS', [
            if (isTour) ...[
              _buildPdfRow(
                booking.checkIn == booking.checkOut ? 'Tour Date' : 'Start Date',
                DateFormat('MMM dd, yyyy').format(booking.checkIn),
              ),
              if (booking.checkIn != booking.checkOut)
                _buildPdfRow('End Date', DateFormat('MMM dd, yyyy').format(booking.checkOut)),
            ] else if (isVehicle) ...[
              _buildPdfRow('Pickup', DateFormat('MMM dd, yyyy HH:mm').format(booking.checkIn)),
              _buildPdfRow('Return', DateFormat('MMM dd, yyyy HH:mm').format(booking.checkOut)),
              if (metadata['pickupLocation'] != null)
                _buildPdfRow('Pickup Loc', metadata['pickupLocation']),
              if (metadata['dropoffLocation'] != null)
                _buildPdfRow('Drop-off Loc', metadata['dropoffLocation']),
            ] else ...[
              _buildPdfRow('Check-in', DateFormat('MMM dd, yyyy').format(booking.checkIn)),
              _buildPdfRow('Check-out', DateFormat('MMM dd, yyyy').format(booking.checkOut)),
            ],
            _buildPdfRow('Guests', _getTravelerBreakdown(booking)),
            if (booking.rooms > 0) _buildPdfRow('Rooms/Units', '${booking.rooms} Rooms'),
            if (booking.specialRequests != null && booking.specialRequests!.isNotEmpty)
              _buildPdfRow('Special Requests', booking.specialRequests!),
          ]),

          pw.SizedBox(height: 20),

          // Payment Info
          _buildSectionWithTitle('PAYMENT INFORMATION', [
            _buildPdfRow(
              'Subtotal',
              '\$${(booking.totalPrice - booking.taxes).toStringAsFixed(2)}',
            ),
            _buildPdfRow('Tax', '\$${booking.taxes.toStringAsFixed(2)}'),
            _buildPdfRow('Total Price', '\$${booking.totalPrice.toStringAsFixed(2)}'),
            _buildPdfRow(
              'Method',
              _formatPdfPaymentMethod(booking.paymentMethod),
            ),
            _buildPdfRow('Payment Status', booking.paymentStatus.name.toUpperCase()),
          ]),

          // ── Multi-lingual Customer Appreciation & Platform Promotion Banner ──
          pw.SizedBox(height: 24),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF8FAFC),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColor.fromInt(0xFFE2E8F0), width: 1),
            ),
            child: pw.Column(
              children: [
                // English Praise & Service App Mention
                pw.Text(
                  'Thank you for choosing ${booking.serviceTitle.isNotEmpty ? booking.serviceTitle : 'our service'}! We are honored to serve you.',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF0F172A),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Book your next stay, vehicle, or tour anytime on SomSafar App.',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 6),

                // Somali Praise
                pw.Text(
                  'Waad ku mahadsan tahay doorashada ${booking.serviceTitle.isNotEmpty ? booking.serviceTitle : 'adeeggeenna'}! Waxaa sharaf noo ah inaan kuu adeegno.',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF1E3A8A),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Safarkaaga & hoygaaga xiga ka dalbo SomSafar App si sahlan oo aamin ah.',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 6),

                // Arabic Praise
                pw.Text(
                  'شكراً لاختياركم ${booking.serviceTitle.isNotEmpty ? booking.serviceTitle : 'خدمتنا'}! يسعدنا ويشرفنا خدمتكم.',
                  textAlign: pw.TextAlign.center,
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    fontWeight: pw.FontWeight.bold,
                    font: fontArabic,
                    color: PdfColor.fromInt(0xFF065F46),
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'احجز رحلتك، إقامتك، وسيارتك القادمة بكل سهولة وأمان عبر تطبيق SomSafar.',
                  textAlign: pw.TextAlign.center,
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(
                    fontSize: 8.5,
                    font: fontArabic,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          // ── Verification Badge Footer ──
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF0F172A),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Official Computer-Generated Receipt · Verified by SomSafar',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.white),
                ),
                pw.Text(
                  'No Signature Required',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey300),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final cleanTitle = booking.serviceTitle.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: '${cleanTitle}_Receipt_${booking.id.toUpperCase()}.pdf',
    );
  }

  static pw.Widget _buildPdfSection(String title, List<pw.Widget> children) {
    return _buildSectionWithTitle(title, children);
  }

  static pw.Widget _buildSectionWithTitle(String title, List<pw.Widget> children) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromInt(0xFF0A3D62),
          ),
        ),
        pw.SizedBox(height: 6),
        ...children,
      ],
    );
  }

  static pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text('$label:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  static String _getTravelerBreakdown(Booking booking) {
    final adults = booking.metadata['adultsCount'] ?? booking.metadata['adult_travelers'];
    final children = booking.metadata['childrenCount'] ?? booking.metadata['child_travelers'];
    final infants = booking.metadata['infantsCount'] ?? booking.metadata['infant_travelers'];

    if (adults == null && children == null && infants == null) {
      return '${booking.guests} Persons';
    }

    final parts = <String>[];
    if (adults != null && adults > 0) {
      parts.add('$adults Adult${adults > 1 ? 's' : ''}');
    }
    if (children != null && children > 0) {
      parts.add('$children Child${children > 1 ? 'ren' : ''}');
    }
    if (infants != null && infants > 0) {
      parts.add('$infants Infant${infants > 1 ? 's' : ''}');
    }

    return parts.isEmpty ? '${booking.guests} Persons' : parts.join(', ');
  }

  static String _formatPdfPaymentMethod(String? method) {
    if (method == null) return 'NOT SPECIFIED';
    final m = method.toLowerCase();
    if (m.contains('card')) return 'CREDIT/DEBIT CARD';
    if (m.contains('mobile')) return 'MOBILE MONEY';
    if (m.contains('bank')) return 'BANK TRANSFER';
    if (m.contains('paylater')) return 'PAY AT ARRIVAL (PAY LATER)';
    return method.replaceAll('PaymentMethod.', '').toUpperCase();
  }
}
