import 'package:intl/intl.dart';

enum TransactionStatus {
  pending,
  successful,
  failed,
  cancelled,
}

class PaymentTransaction {
  final String id;
  final String bookingId;
  final String userId;
  final String invoiceId;
  final String referenceId;
  final double amount;
  final String paymentMethod;
  final TransactionStatus status;
  final Map<String, dynamic> waafipayResponse;
  final DateTime createdAt;

  PaymentTransaction({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.invoiceId,
    required this.referenceId,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.waafipayResponse,
    required this.createdAt,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      userId: json['user_id'] as String,
      invoiceId: json['invoice_id'] as String,
      referenceId: json['reference_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      status: _parseStatus(json['transaction_status'] as String),
      waafipayResponse: json['waafipay_response'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'booking_id': bookingId,
      'user_id': userId,
      'invoice_id': invoiceId,
      'reference_id': referenceId,
      'amount': amount,
      'payment_method': paymentMethod,
      'transaction_status': status.name.toUpperCase(),
      'waafipay_response': waafipayResponse,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static TransactionStatus _parseStatus(String status) {
    switch (status.toUpperCase()) {
      case 'SUCCESSFUL':
        return TransactionStatus.successful;
      case 'FAILED':
        return TransactionStatus.failed;
      case 'CANCELLED':
        return TransactionStatus.cancelled;
      default:
        return TransactionStatus.pending;
    }
  }

  String get formattedDate => DateFormat('MMM d, yyyy HH:mm').format(createdAt);
  String get formattedAmount => '\$${amount.toStringAsFixed(2)}';
}
