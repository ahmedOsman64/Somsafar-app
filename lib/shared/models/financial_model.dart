class FinancialMetrics {
  final double totalRevenue;
  final double platformFees;
  final double pendingPayouts;
  final List<double> weeklyRevenue; // 7 days of revenue data

  const FinancialMetrics({
    required this.totalRevenue,
    required this.platformFees,
    required this.pendingPayouts,
    required this.weeklyRevenue,
  });
}

class Transaction {
  final String id;
  final String userName;
  final double amount;
  final String status; // 'Completed', 'Pending', 'Refunded'
  final DateTime date;
  final String? providerId;
  final String? providerName;
  final String? receivingAccount;

  const Transaction({
    required this.id,
    required this.userName,
    required this.amount,
    required this.status,
    required this.date,
    this.providerId,
    this.providerName,
    this.receivingAccount,
  });
}
