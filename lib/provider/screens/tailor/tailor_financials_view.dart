import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/tailor_provider.dart';
import '../../../shared/models/tailor_models.dart';
import '../../../shared/models/user_model.dart';

class TailorFinancialsView extends ConsumerWidget {
  const TailorFinancialsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tailorState = ref.watch(tailorProvider);

    // Calculate financials
    double totalRevenue = 0.0;
    double totalDeposits = 0.0;
    double totalOutstanding = 0.0;
    double dailyRevenue = 0.0;

    final now = DateTime.now();

    for (final order in tailorState.orders) {
      totalRevenue += order.price;
      totalDeposits += order.deposit;
      
      if (order.status != TailorOrderStatus.taken) {
        totalOutstanding += order.balance;
      }
      
      // Calculate daily revenue: deposits made today + balances paid today (assuming taken orders completed/paid today)
      if (order.createdAt.year == now.year &&
          order.createdAt.month == now.month &&
          order.createdAt.day == now.day) {
        dailyRevenue += order.deposit;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Xisaabaadka & Dakhliga (Financials)', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0D3B66),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Daily Revenue Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D3B66), Color(0xFF1B62A4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D3B66).withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dakhliga Maanta (Daily Revenue)',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${dailyRevenue.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Taariikhda: ${DateFormat.yMMMMd().format(now)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Financial Summary Metrics Cards
            const Text(
              'Warbixinta Xisaabaadka (Ledger)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0C2340),
              ),
            ),
            const SizedBox(height: 16),
            _buildFinancialRow(
              context,
              'Qiimaha Dalabaadka (Total Booked Revenue)',
              '\$${totalRevenue.toStringAsFixed(2)}',
              Icons.trending_up,
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildFinancialRow(
              context,
              'Hormaris la Bixiyay (Total Deposits Received)',
              '\$${totalDeposits.toStringAsFixed(2)}',
              Icons.check_circle_outline,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildFinancialRow(
              context,
              'Haraaga Dhiman (Outstanding Balances)',
              '\$${totalOutstanding.toStringAsFixed(2)}',
              Icons.error_outline,
              Colors.red,
            ),
            const SizedBox(height: 28),

            // Transaction / Order List Ledger
            const Text(
              'Diiwaanka Lacag-bixinta (Payment Log)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0C2340),
              ),
            ),
            const SizedBox(height: 16),

            if (tailorState.orders.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: const Center(
                  child: Text(
                    'Ma jiraan dalabaad iyo lacag-bixin diiwaangashan.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tailorState.orders.length,
                itemBuilder: (context, index) {
                  final order = tailorState.orders[index];
                  final customer = tailorState.customers.firstWhere(
                    (c) => c.id == order.customerId,
                    orElse: () => TailorCustomer(
                      id: '',
                      name: 'Macmiil aan la aqoon',
                      phone: '',
                      gender: Gender.male,
                      shoulder: 0,
                      chest: 0,
                      waist: 0,
                      hips: 0,
                      sleeveLength: 0,
                      overallLength: 0,
                      notes: '',
                      updatedAt: DateTime.now(),
                    ),
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[100]!),
                    ),
                    color: Colors.white,
                    elevation: 0,
                    child: ListTile(
                      title: Text(
                        customer.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${order.fabricType} • ${DateFormat.yMMMd().format(order.createdAt)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '+\$${order.deposit.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          if (order.balance > 0 && order.status != TailorOrderStatus.taken)
                            Text(
                              'Haraa: \$${order.balance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            const Text(
                              'Guud ahaan Bixiyay',
                              style: TextStyle(
                                color: Colors.blueGrey,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialRow(
    BuildContext context,
    String label,
    String amount,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: Color(0xFF4A4A4A),
                ),
              ),
            ],
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
