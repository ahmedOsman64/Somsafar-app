import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive.dart';
import '../../shared/models/discount_model.dart';
import '../../shared/services/discount_repository.dart';
import '../../shared/widgets/confirmation_dialog.dart';
import 'create_discount_screen.dart';

final discountTabFilterProvider = StateProvider<String>((ref) => 'all');

class ProviderDiscountsScreen extends ConsumerStatefulWidget {
  const ProviderDiscountsScreen({super.key});

  @override
  ConsumerState<ProviderDiscountsScreen> createState() =>
      _ProviderDiscountsScreenState();
}

class _ProviderDiscountsScreenState
    extends ConsumerState<ProviderDiscountsScreen> {
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
    final activeTab = ref.watch(discountTabFilterProvider);

    final activeCount =
        discounts.where((d) => d.status == DiscountStatus.active).length;
    final scheduledCount =
        discounts.where((d) => d.status == DiscountStatus.scheduled).length;
    final endedCount =
        discounts.where((d) => d.status == DiscountStatus.ended).length;
    final inactiveCount =
        discounts.where((d) => d.status == DiscountStatus.inactive).length;

    List<Discount> displayedDiscounts;
    if (activeTab == 'active') {
      displayedDiscounts =
          discounts.where((d) => d.status == DiscountStatus.active).toList();
    } else if (activeTab == 'scheduled') {
      displayedDiscounts =
          discounts.where((d) => d.status == DiscountStatus.scheduled).toList();
    } else if (activeTab == 'expired') {
      displayedDiscounts =
          discounts.where((d) => d.status == DiscountStatus.ended).toList();
    } else if (activeTab == 'inactive') {
      displayedDiscounts =
          discounts.where((d) => d.status == DiscountStatus.inactive).toList();
    } else {
      displayedDiscounts = [...discounts];
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Full-Width Gradient Header Banner ────────────────
            _buildHeader(
              context,
              activeTab,
              discounts.length,
              activeCount,
              scheduledCount,
              endedCount,
              inactiveCount,
            ),

            const SizedBox(height: 20),

            // ── Responsive Stat Cards ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final cardWidth = isMobile
                      ? (constraints.maxWidth - 12) / 2
                      : (constraints.maxWidth - 36) / 4;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildStatCard(
                        width: cardWidth,
                        label: 'Active Offers',
                        value: activeCount.toString(),
                        subtitle: 'Live discounts now',
                        icon: Icons.check_circle_rounded,
                        color: const Color(0xFF10B981),
                      ),
                      _buildStatCard(
                        width: cardWidth,
                        label: 'Scheduled',
                        value: scheduledCount.toString(),
                        subtitle: 'Upcoming promos',
                        icon: Icons.calendar_today_rounded,
                        color: const Color(0xFF3B82F6),
                      ),
                      _buildStatCard(
                        width: cardWidth,
                        label: 'Expired',
                        value: endedCount.toString(),
                        subtitle: 'Past deals',
                        icon: Icons.history_rounded,
                        color: const Color(0xFF64748B),
                      ),
                      _buildStatCard(
                        width: cardWidth,
                        label: 'Inactive',
                        value: inactiveCount.toString(),
                        subtitle: 'Paused offers',
                        icon: Icons.pause_circle_rounded,
                        color: const Color(0xFFEF4444),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // ── Promotions Voucher List / Empty State ───────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: displayedDiscounts.isEmpty
                  ? _buildEmptyState(context, activeTab)
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: displayedDiscounts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) => _buildDiscountCard(
                        context,
                        ref,
                        displayedDiscounts[index],
                      ),
                    ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String activeTab,
    int totalCount,
    int activeCount,
    int scheduledCount,
    int endedCount,
    int inactiveCount,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(context.isMobile ? 0 : 32),
          bottomRight: Radius.circular(context.isMobile ? 0 : 32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, context.isMobile ? 24 : 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.local_offer_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Promotions & Discounts',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Create promotional vouchers & boost sales',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateDiscountScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Create New'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Tab Pill Selector Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabPill(
                      'All Promotions',
                      'all',
                      totalCount,
                      activeTab,
                    ),
                    const SizedBox(width: 8),
                    _buildTabPill(
                      'Active',
                      'active',
                      activeCount,
                      activeTab,
                    ),
                    const SizedBox(width: 8),
                    _buildTabPill(
                      'Scheduled',
                      'scheduled',
                      scheduledCount,
                      activeTab,
                    ),
                    const SizedBox(width: 8),
                    _buildTabPill(
                      'Expired',
                      'expired',
                      endedCount,
                      activeTab,
                    ),
                    const SizedBox(width: 8),
                    _buildTabPill(
                      'Inactive',
                      'inactive',
                      inactiveCount,
                      activeTab,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabPill(
    String label,
    String key,
    int count,
    String activeTab,
  ) {
    final isSelected = activeTab == key;
    return GestureDetector(
      onTap: () {
        ref.read(discountTabFilterProvider.notifier).state = key;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondary : Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.secondary
                : Colors.white.withAlpha(40),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withAlpha(50)
                      : Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required double width,
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String activeTab) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.confirmation_number_outlined,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            activeTab == 'all'
                ? 'No promotions created yet'
                : 'No $activeTab promotions found',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first promotional discount voucher to attract more travelers & boost bookings.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateDiscountScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Create First Offer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountCard(
    BuildContext context,
    WidgetRef ref,
    Discount discount,
  ) {
    final startFormatted = DateFormat('MMM d, yyyy').format(discount.startDate);
    final endFormatted = DateFormat('MMM d, yyyy').format(discount.endDate);

    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            // Left Coupon Voucher Stub
            Container(
              width: 110,
              decoration: BoxDecoration(
                color: discount.statusColor.withAlpha(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
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
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'OFF',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: discount.statusColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            // Dashed Ticket Separator Line
            SizedBox(
              width: 16,
              child: Column(
                children: List.generate(
                  8,
                  (index) => Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: Colors.grey[200],
                    ),
                  ),
                ),
              ),
            ),

            // Right Info Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            discount.discountText,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: discount.statusColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            discount.status.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: discount.statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.calendar_month_rounded,
                            size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$startFormatted - $endFormatted',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.more_horiz_rounded,
                              color: Colors.grey[600]),
                          onSelected: (value) {
                            if (value == 'edit') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CreateDiscountScreen(
                                    discountToEdit: discount,
                                  ),
                                ),
                              );
                            } else if (value == 'delete') {
                              _showDeleteDialog(context, ref, discount);
                            } else if (value == 'toggle_status') {
                              _toggleDiscountStatus(context, ref, discount);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit Promotion'),
                            ),
                            PopupMenuItem(
                              value: 'toggle_status',
                              child: Text(
                                discount.status == DiscountStatus.inactive
                                    ? 'Activate'
                                    : 'Deactivate',
                              ),
                            ),
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
                  ],
                ),
              ),
            ),
          ],
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
          SnackBar(
            content: const Text('Discount deleted successfully!'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
          backgroundColor:
              isDeactivating ? Colors.orange : const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}
