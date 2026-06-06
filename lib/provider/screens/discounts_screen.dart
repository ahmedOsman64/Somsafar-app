import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/discount_model.dart';
import '../../shared/services/discount_repository.dart';
import 'create_discount_screen.dart';
import '../../shared/widgets/confirmation_dialog.dart';

class ProviderDiscountsScreen extends ConsumerStatefulWidget {
  const ProviderDiscountsScreen({super.key});

  @override
  ConsumerState<ProviderDiscountsScreen> createState() =>
      _ProviderDiscountsScreenState();
}

class _ProviderDiscountsScreenState extends ConsumerState<ProviderDiscountsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(discountRepositoryProvider.notifier).checkExpirations();
    });
  }

  @override
  Widget build(BuildContext context) {
    final discounts = ref.watch(filteredDiscountsProvider);

    // Calculate stats
    final activeCount =
        discounts.where((d) => d.status == DiscountStatus.active).length;
    final scheduledCount =
        discounts.where((d) => d.status == DiscountStatus.scheduled).length;
    final endedCount =
        discounts.where((d) => d.status == DiscountStatus.ended).length;
    final inactiveCount =
        discounts.where((d) => d.status == DiscountStatus.inactive).length;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 0, // Hidden but needed for TabBar
          bottom: TabBar(
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.secondary,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'All Promotions'),
              Tab(text: 'Active'),
              Tab(text: 'Scheduled'),
              Tab(text: 'Expired'),
              Tab(text: 'Inactive'),
            ],
          ),
        ),
        body: Column(
          children: [
            // Premium Header with Stats
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Promotions & Discounts',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage your offers and attract more bookings',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      _buildCreateButton(context),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildStatCard(
                          'Active',
                          activeCount.toString(),
                          Icons.check_circle_outline,
                          Colors.green,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          'Scheduled',
                          scheduledCount.toString(),
                          Icons.calendar_today_outlined,
                          Colors.blue,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          'Expired',
                          endedCount.toString(),
                          Icons.history,
                          Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          'Inactive',
                          inactiveCount.toString(),
                          Icons.pause_circle_outline,
                          Colors.red,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Tab View Content
            Expanded(
              child: TabBarView(
                children: [
                  _buildDiscountList(context, ref, discounts),
                  _buildDiscountList(
                    context,
                    ref,
                    discounts.where((d) => d.status == DiscountStatus.active).toList(),
                  ),
                  _buildDiscountList(
                    context,
                    ref,
                    discounts.where((d) => d.status == DiscountStatus.scheduled).toList(),
                  ),
                  _buildDiscountList(
                    context,
                    ref,
                    discounts.where((d) => d.status == DiscountStatus.ended).toList(),
                  ),
                  _buildDiscountList(
                    context,
                    ref,
                    discounts.where((d) => d.status == DiscountStatus.inactive).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateDiscountScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add, color: Colors.white, size: 20),
        label: const Text(
          'Create New',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountList(
    BuildContext context,
    WidgetRef ref,
    List<Discount> filteredList,
  ) {
    if (filteredList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Icon(
                Icons.confirmation_number_outlined,
                size: 64,
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No active promotions',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Start by creating your first discount to attract more travelers.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], height: 1.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: filteredList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        return _buildDiscountCard(context, ref, filteredList[index]);
      },
    );
  }

  Widget _buildDiscountCard(
    BuildContext context,
    WidgetRef ref,
    Discount discount,
  ) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Status Indicator Bar
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 6,
              child: Container(color: discount.statusColor),
            ),
            Row(
              children: [
                // Left Side: Value & Pattern
                Container(
                  width: 100,
                  decoration: BoxDecoration(
                    color: discount.statusColor.withValues(alpha: 0.05),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        discount.value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: discount.statusColor,
                          height: 1,
                        ),
                      ),
                      Text(
                        discount.isPercentage ? '%' : '\$',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: discount.statusColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'OFF',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: discount.statusColor.withValues(alpha: 0.6),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Dashed Separator (Custom design with circles)
                SizedBox(
                  width: 20,
                  child: Column(
                    children: List.generate(
                      6,
                      (index) => Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: Colors.grey[200],
                        ),
                      ),
                    ),
                  ),
                ),

                // Right Side: Info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                discount.discountText,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildStatusBadge(discount),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${discount.startDate.day}/${discount.startDate.month} - ${discount.endDate.day}/${discount.endDate.month}',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                            const Spacer(),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.more_horiz, color: Colors.grey),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          CreateDiscountScreen(discountToEdit: discount),
                                    ),
                                  );
                                } else if (value == 'delete') {
                                  _showDeleteDialog(context, ref, discount);
                                } else if (value == 'toggle_status') {
                                  _toggleDiscountStatus(context, ref, discount);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(
                                  value: 'toggle_status',
                                  child: Text(discount.status == DiscountStatus.inactive
                                      ? 'Activate'
                                      : 'Deactivate'),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Discount discount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: discount.statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        discount.status.name.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: discount.statusColor,
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    Discount discount,
  ) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Delete Discount?',
      message: 'Are you sure you want to delete "${discount.discountText}"?',
      confirmLabel: 'Yes, Delete',
      type: ConfirmationDialogType.danger,
      icon: Icons.delete_forever_outlined,
    );

    if (confirmed == true) {
      await ref
          .read(discountRepositoryProvider.notifier)
          .deleteDiscount(discount.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Discount deleted successfully!'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _toggleDiscountStatus(
    BuildContext context,
    WidgetRef ref,
    Discount discount,
  ) async {
    final isDeactivating = discount.status != DiscountStatus.inactive;
    
    await ref
        .read(discountRepositoryProvider.notifier)
        .toggleDiscountStatus(discount);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isDeactivating 
                ? 'Discount deactivated successfully!' 
                : 'Discount activated successfully!',
          ),
          backgroundColor: isDeactivating ? Colors.orange : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
