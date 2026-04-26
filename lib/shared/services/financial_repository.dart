import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/financial_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'system_settings_repository.dart';
import '../../core/services/supabase_service.dart';

class FinancialState {
  final FinancialMetrics metrics;
  final List<Transaction> transactions;

  const FinancialState({required this.metrics, required this.transactions});

  FinancialState copyWith({
    FinancialMetrics? metrics,
    List<Transaction>? transactions,
  }) {
    return FinancialState(
      metrics: metrics ?? this.metrics,
      transactions: transactions ?? this.transactions,
    );
  }
}

class FinancialRepository extends StateNotifier<FinancialState> {
  final Ref _ref;
  FinancialRepository(this._ref)
    : super(
        const FinancialState(
          metrics: FinancialMetrics(
            totalRevenue: 0.0,
            platformFees: 0.0,
            pendingPayouts: 0.0,
            weeklyRevenue: [0, 0, 0, 0, 0, 0, 0],
          ),
          transactions: [],
        ),
      );

  void _initStream(User? user) {
    if (user == null) {
      debugPrint('FinancialRepository: No user, skipping stream.');
      return;
    }

    debugPrint('FinancialRepository: Initializing stream for role ${user.role}...');

    // Security: Role-based filtering
    if (user.role == UserRole.provider || user.role == UserRole.providerHelper) {
      final providerKey = user.providerId ?? user.id;
      debugPrint('FinancialRepository: Filtering for provider_id: $providerKey');
      
      SupabaseConfig.client
          .from('payments')
          .stream(primaryKey: ['id'])
          .eq('provider_id', providerKey)
          .listen(
            (data) => _processData(data),
            onError: (error) => debugPrint('FinancialRepository: Stream error: $error'),
          );
    } else if (user.role == UserRole.admin) {
      // Admins see everything
      debugPrint('FinancialRepository: Admin access, streaming all payments.');
      SupabaseConfig.client
          .from('payments')
          .stream(primaryKey: ['id'])
          .listen(
            (data) => _processData(data),
            onError: (error) => debugPrint('FinancialRepository: Stream error: $error'),
          );
    } else if (user.role == UserRole.traveler) {
      // Travelers see their own payments (linked via booking_id -> traveler_id)
      // Note: Supabase streams don't support complex joins, so we rely on RLS 
      // or a specific traveler_id column if it were added.
      // Based on our RLS policy, simply streaming without filter works because RLS filters it.
      debugPrint('FinancialRepository: Traveler access, streaming related payments.');
      SupabaseConfig.client
          .from('payments')
          .stream(primaryKey: ['id'])
          .listen(
            (data) => _processData(data),
            onError: (error) => debugPrint('FinancialRepository: Stream error: $error'),
          );
    }
  }

  void _processData(List<Map<String, dynamic>> data) {
    if (!mounted) return;

    try {
      final txs = data.map((res) {
        return Transaction(
          id: res['id'] ?? '',
          userName: res['user_name'] ?? 'Unknown',
          amount: (res['amount'] as num?)?.toDouble() ?? 0.0,
          status: res['status'] == 'successful'
              ? 'Completed'
              : res['status'] == 'failed'
              ? 'Failed'
              : 'Pending',
          date: res['created_at'] != null
              ? DateTime.parse(res['created_at'])
              : DateTime.now(),
          providerId: res['provider_id'],
          providerName: res['provider_name'],
          receivingAccount: res['payout_account'],
        );
      }).toList();

      // Sort recent first
      txs.sort((a, b) => b.date.compareTo(a.date));

      // Calculate metrics based on all transactions
      double totalRev = 0;
      double pendingPayouts = 0;
      List<double> weeklyRev = List.filled(7, 0.0);

      final now = DateTime.now();

      for (var tx in txs) {
        if (tx.status == 'Completed') {
          totalRev += tx.amount;

          final daysDiff = now.difference(tx.date).inDays;
          if (daysDiff >= 0 && daysDiff < 7) {
            weeklyRev[6 - daysDiff] += tx.amount;
          }
        } else if (tx.status == 'Pending') {
          pendingPayouts += tx.amount;
        }
      }

      final feePercent = _ref.read(systemSettingsProvider).platformFee;
      final newMetrics = FinancialMetrics(
        totalRevenue: totalRev,
        platformFees: totalRev * (feePercent / 100),
        pendingPayouts: pendingPayouts,
        weeklyRevenue: weeklyRev,
      );

      state = state.copyWith(metrics: newMetrics, transactions: txs);
    } catch (e) {
      debugPrint('FinancialRepository: Error processing data: $e');
    }
  }

  Future<void> addTransaction({
    required String userName,
    required double amount,
    required String bookingId,
    bool isPaid = true,
    String? providerId,
    String? providerName,
    String? receivingAccount,
  }) async {
    try {
      await SupabaseConfig.client.from('payments').insert({
        'booking_id': bookingId,
        'user_name': userName,
        'amount': amount,
        'payment_method': 'System',
        'status': isPaid ? 'successful' : 'pending',
        'provider_id': providerId,
        'provider_name': providerName,
        'payout_account': receivingAccount,
      });
    } catch (e) {
      debugPrint('Insert payment error: $e');
    }
  }
}

final financialProvider =
    StateNotifierProvider<FinancialRepository, FinancialState>((ref) {
  final user = ref.watch(authProvider);
  final repo = FinancialRepository(ref);
  repo._initStream(user);
  return repo;
});
