import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/responsive.dart';
import '../providers/analysis_provider.dart';

class ProviderAnalysisScreen extends ConsumerWidget {
  const ProviderAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(analysisStatsProvider);
    final timeframe = ref.watch(analysisTimeframeProvider);
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header Banner ──────────────────────────────────
            _buildHeader(context, ref, stats, timeframe, currencyFormat),

                const SizedBox(height: 20),

                // ── KPI Summary Cards ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 650;
                      final cardWidth = isMobile
                          ? (constraints.maxWidth - 12) / 2
                          : (constraints.maxWidth - 36) / 4;

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildKpiCard(
                            width: cardWidth,
                            title: 'Total Revenue',
                            value: currencyFormat.format(stats.totalRevenue),
                            subtitle: '\$${stats.pendingPayout.toStringAsFixed(0)} pending',
                            icon: Icons.account_balance_wallet_rounded,
                            color: AppColors.primary,
                          ),
                          _buildKpiCard(
                            width: cardWidth,
                            title: 'Total Bookings',
                            value: stats.totalBookings.toString(),
                            subtitle: '${stats.completedBookings} completed',
                            icon: Icons.bookmark_added_rounded,
                            color: const Color(0xFF10B981),
                          ),
                          _buildKpiCard(
                            width: cardWidth,
                            title: 'Average Value',
                            value: currencyFormat.format(stats.averageBookingValue),
                            subtitle: 'Per confirmed order',
                            icon: Icons.trending_up_rounded,
                            color: const Color(0xFF6366F1),
                          ),
                          _buildKpiCard(
                            width: cardWidth,
                            title: 'Completion Rate',
                            value: '${stats.completionRate.toStringAsFixed(1)}%',
                            subtitle: 'Successful bookings',
                            icon: Icons.pie_chart_outline_rounded,
                            color: const Color(0xFFF59E0B),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // ── Revenue Bar Chart & Status Breakdown Pie Chart ─
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth > 800;
                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildRevenueChartCard(context, stats, timeframe, currencyFormat),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: _buildStatusPieChartCard(context, stats),
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _buildRevenueChartCard(context, stats, timeframe, currencyFormat),
                          const SizedBox(height: 16),
                          _buildStatusPieChartCard(context, stats),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // ── Top Performing Services & Insights ───────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth > 800;
                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildTopServicesCard(context, stats, currencyFormat),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: _buildInsightsCard(stats),
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _buildTopServicesCard(context, stats, currencyFormat),
                          const SizedBox(height: 16),
                          _buildInsightsCard(stats),
                        ],
                      );
                    },
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
    WidgetRef ref,
    AnalysisStats stats,
    AnalysisTimeframe timeframe,
    NumberFormat currencyFormat,
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
                          color: Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.analytics_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Performance Analytics',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Real-time financial & booking metrics',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withAlpha(35),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF10B981).withAlpha(90)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 14),
                            SizedBox(width: 5),
                            Text(
                              'Supabase RLS Active',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/provider/reports'),
                        icon: const Icon(Icons.receipt_long_rounded, size: 16),
                        label: const Text('Transactions Log'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withAlpha(30),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.white.withAlpha(50)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Timeframe Switcher
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTimeframeBtn(ref, 'Weekly', AnalysisTimeframe.weekly, timeframe),
                    _buildTimeframeBtn(ref, 'Monthly', AnalysisTimeframe.monthly, timeframe),
                    _buildTimeframeBtn(ref, 'Yearly', AnalysisTimeframe.yearly, timeframe),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeframeBtn(
    WidgetRef ref,
    String label,
    AnalysisTimeframe target,
    AnalysisTimeframe current,
  ) {
    final isSelected = target == current;
    return GestureDetector(
      onTap: () {
        ref.read(analysisTimeframeProvider.notifier).state = target;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF0F172A) : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required double width,
    required String title,
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
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChartCard(
    BuildContext context,
    AnalysisStats stats,
    AnalysisTimeframe timeframe,
    NumberFormat currencyFormat,
  ) {
    final maxVal = stats.chartData.isEmpty
        ? 100.0
        : stats.chartData.reduce((a, b) => a > b ? a : b);
    final maxY = maxVal == 0 ? 100.0 : maxVal * 1.25;

    return Container(
      padding: const EdgeInsets.all(20),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Revenue Overview',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Earnings trend for current selection',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  currencyFormat.format(stats.totalRevenue),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: stats.chartData.every((v) => v == 0)
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bar_chart_rounded,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text(
                          'No revenue recorded for this timeframe',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : BarChart(
                    BarChartData(
                      maxY: maxY,
                      alignment: BarChartAlignment.spaceAround,
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 4,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.grey[200],
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const SizedBox();
                              return Text(
                                '\$${value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : value.toInt()}',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 10),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= stats.chartLabels.length) {
                                return const SizedBox();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  stats.chartLabels[idx],
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: List.generate(stats.chartData.length, (i) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: stats.chartData[i],
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF1E3A8A)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              width: timeframe == AnalysisTimeframe.yearly ? 12 : 18,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPieChartCard(BuildContext context, AnalysisStats stats) {
    final hasData = stats.totalBookings > 0;

    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Booking Distribution',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Status breakdown of all orders',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 170,
            child: !hasData
                ? Center(
                    child: Text(
                      'No bookings to display',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  )
                : PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 38,
                      sections: [
                        if (stats.completedBookings > 0)
                          PieChartSectionData(
                            color: const Color(0xFF10B981),
                            value: stats.completedBookings.toDouble(),
                            title: '${stats.completedBookings}',
                            radius: 35,
                            titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        if (stats.confirmedBookings > 0)
                          PieChartSectionData(
                            color: const Color(0xFF3B82F6),
                            value: stats.confirmedBookings.toDouble(),
                            title: '${stats.confirmedBookings}',
                            radius: 35,
                            titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        if (stats.pendingBookings > 0)
                          PieChartSectionData(
                            color: const Color(0xFFF59E0B),
                            value: stats.pendingBookings.toDouble(),
                            title: '${stats.pendingBookings}',
                            radius: 35,
                            titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        if (stats.cancelledBookings > 0)
                          PieChartSectionData(
                            color: const Color(0xFFEF4444),
                            value: stats.cancelledBookings.toDouble(),
                            title: '${stats.cancelledBookings}',
                            radius: 35,
                            titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildLegendItem('Completed', const Color(0xFF10B981)),
              _buildLegendItem('Confirmed', const Color(0xFF3B82F6)),
              _buildLegendItem('Pending', const Color(0xFFF59E0B)),
              _buildLegendItem('Cancelled', const Color(0xFFEF4444)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildTopServicesCard(
    BuildContext context,
    AnalysisStats stats,
    NumberFormat currencyFormat,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Top Performing Services',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Ranked by gross revenue generated',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          if (stats.topServices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No service earnings recorded yet',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stats.topServices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final item = stats.topServices[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${index + 1}. ${item.title}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          currencyFormat.format(item.revenue),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: item.percentage / 100,
                        minHeight: 6,
                        backgroundColor: Colors.grey[100],
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard(AnalysisStats stats) {
    String insightText = 'Keep adding quality services and offering discounts to boost customer bookings!';
    IconData insightIcon = Icons.lightbulb_outline_rounded;
    Color insightColor = const Color(0xFF3B82F6);

    if (stats.completionRate >= 80) {
      insightText = 'Outstanding completion rate! Your service reliability is building great customer trust.';
      insightIcon = Icons.star_rounded;
      insightColor = const Color(0xFF10B981);
    } else if (stats.pendingBookings > 0) {
      insightText = 'You have ${stats.pendingBookings} pending booking request(s) awaiting approval or payment collection.';
      insightIcon = Icons.notifications_active_rounded;
      insightColor = const Color(0xFFF59E0B);
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
          const Text(
            'Business Insights',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Smart suggestions for growth',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: insightColor.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: insightColor.withAlpha(40)),
            ),
            child: Row(
              children: [
                Icon(insightIcon, color: insightColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    insightText,
                    style: TextStyle(
                      fontSize: 13,
                      color: insightColor.withAlpha(220),
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
