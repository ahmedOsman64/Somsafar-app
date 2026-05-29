import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/discount_model.dart';
import '../../shared/services/discount_repository.dart';
import '../../shared/widgets/confirmation_dialog.dart';

class AdminDiscountsScreen extends ConsumerStatefulWidget {
  const AdminDiscountsScreen({super.key});

  @override
  ConsumerState<AdminDiscountsScreen> createState() =>
      _AdminDiscountsScreenState();
}

class _AdminDiscountsScreenState extends ConsumerState<AdminDiscountsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(discountRepositoryProvider.notifier).checkExpirations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final allDiscounts = ref.watch(discountRepositoryProvider);

    // Calculate stats
    final pendingCount = allDiscounts
        .where((d) => d.status == DiscountStatus.pending)
        .length;
    final activeCount = allDiscounts
        .where((d) => d.status == DiscountStatus.active)
        .length;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text('Manage Discounts'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'All'),
              Tab(text: 'Pending'),
              Tab(text: 'Active'),
              Tab(text: 'Expired'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  _buildStatTile('Pending', pendingCount, Colors.orange),
                  const SizedBox(width: 12),
                  _buildStatTile('Active', activeCount, Colors.green),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildList(allDiscounts),
                  _buildList(
                    allDiscounts
                        .where((d) => d.status == DiscountStatus.pending)
                        .toList(),
                  ),
                  _buildList(
                    allDiscounts
                        .where((d) => d.status == DiscountStatus.active)
                        .toList(),
                  ),
                  _buildList(
                    allDiscounts
                        .where((d) => d.status == DiscountStatus.ended)
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            Text(
              count.toString(),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Discount> list) {
    if (list.isEmpty) {
      return const Center(child: Text('No discounts found'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final d = list[index];
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: d.statusColor.withValues(alpha: 0.1),
              child: Text(
                d.isPercentage ? '%' : r'$',
                style: TextStyle(
                  color: d.statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              d.discountText,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Provider: ${d.providerId}'),
                Text(
                  '${d.startDate.day}/${d.startDate.month} - ${d.endDate.day}/${d.endDate.month}',
                ),
                Text(
                  'Status: ${d.status.name.toUpperCase()}',
                  style: TextStyle(
                    color: d.statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (d.status == DiscountStatus.pending)
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () => _updateStatus(d, DiscountStatus.active),
                    tooltip: 'Approve & Activate',
                  )
                else
                  Switch(
                    value: d.status == DiscountStatus.active,
                    activeThumbColor: Colors.green,
                    onChanged: (val) {
                      _updateStatus(
                        d,
                        val ? DiscountStatus.active : DiscountStatus.ended,
                      );
                    },
                  ),
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'delete') {
                      _deleteDiscount(d);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _updateStatus(Discount d, DiscountStatus newStatus) {
    final updated = Discount(
      id: d.id,
      providerId: d.providerId,
      value: d.value,
      isPercentage: d.isPercentage,
      startDate: d.startDate,
      endDate: d.endDate,
      applicableServiceIds: d.applicableServiceIds,
      status: newStatus,
      title: d.title,
      description: d.description,
      imageUrl: d.imageUrl,
      code: d.code,
      createdAt: d.createdAt,
    );
    ref.read(discountRepositoryProvider.notifier).updateDiscount(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Status updated to ${newStatus.name.toUpperCase()}'),
        backgroundColor: newStatus == DiscountStatus.active
            ? Colors.green
            : Colors.orange,
      ),
    );
  }

  void _deleteDiscount(Discount d) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete Discount?',
      message: 'Are you sure you want to delete this discount?',
      type: ConfirmationDialogType.danger,
    );
    if (confirmed == true) {
      ref.read(discountRepositoryProvider.notifier).deleteDiscount(d.id);
    }
  }
}
