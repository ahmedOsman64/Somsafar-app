import os

filepath = r"d:\New folder\SomSafar\lib\provider\screens\dashboard_screen.dart"

with open(filepath, 'r') as f:
    content = f.read()

content = content.replace("import 'package:provider/provider.dart';", "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport '../../shared/services/auth_service.dart';\nimport '../../shared/models/user_model.dart';")

content = content.replace(
"""class ProviderDashboardScreen extends StatelessWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardProvider(),
      child: const _DashboardScreenContent(),
    );
  }
}""",
"""class ProviderDashboardScreen extends StatelessWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DashboardScreenContent();
  }
}"""
)

content = content.replace(
"""class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner();

  @override
  Widget build(BuildContext context) {""",
"""class _WelcomeBanner extends ConsumerWidget {
  const _WelcomeBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final userName = user?.name.split(' ').first ?? 'Provider';"""
)

content = content.replace(
"""                Text(
                  'Good Evening, Ahmed!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Your hotels are performing 15% better than last week. Keep up the great work!',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),""",
"""                Text(
                  'Welcome back, $userName!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Here is the latest overview of your services and bookings.',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),"""
)

# Replace ConsumerWidgets
content = content.replace(
"""class _RevenueProgressCard extends StatelessWidget {
  const _RevenueProgressCard();

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();""",
"""class _RevenueProgressCard extends ConsumerWidget {
  const _RevenueProgressCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardStatsProvider);"""
)

content = content.replace(
"""class _EarningsChartSection extends StatelessWidget {
  const _EarningsChartSection();

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();""",
"""class _EarningsChartSection extends ConsumerWidget {
  const _EarningsChartSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardStatsProvider);"""
)

content = content.replace(
"""class _RecentBookingsSection extends StatelessWidget {
  const _RecentBookingsSection();

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();""",
"""class _RecentBookingsSection extends ConsumerWidget {
  const _RecentBookingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardStatsProvider);"""
)

overview_start = """class _OverviewSection extends StatelessWidget {
  const _OverviewSection();

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();"""

overview_replacement = """class _OverviewSection extends ConsumerWidget {
  const _OverviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardStatsProvider);
    final user = ref.watch(authProvider);
    final providerType = user?.providerType ?? ProviderType.hotel;
    
    String servicesLabel = 'Hotels';
    IconData servicesIcon = Icons.bed_outlined;
    
    switch (providerType) {
      case ProviderType.hotel:
      case ProviderType.home:
      case ProviderType.apartment:
        servicesLabel = 'Properties';
        servicesIcon = Icons.apartment;
        break;
      case ProviderType.transport:
      case ProviderType.tour:
        servicesLabel = 'Tours';
        servicesIcon = Icons.directions_bus;
        break;
    }"""
content = content.replace(overview_start, overview_replacement)

# Replace _StatCard mappings inside _OverviewSection
stat_cards = """                _StatCard(
                  icon: Icons.bed_outlined,
                  count: dashboard.totalHotels,
                  label: 'Hotels',
                  color: Colors.blue,
                ),
                _StatCard(
                  icon: Icons.fact_check_outlined,
                  count: dashboard.activeRooms,
                  label: 'Active',
                  color: Colors.green,
                ),
                _StatCard(
                  icon: Icons.hotel_class_outlined,
                  count: dashboard.inactiveRooms,
                  label: 'Inactive',
                  color: Colors.orange,
                ),
                _StatCard(
                  icon: Icons.edit_note,
                  count: dashboard.draftListings,
                  label: 'Drafts',
                  color: Colors.grey,
                ),
                _StatCard(
                  icon: Icons.assignment_outlined,
                  count: dashboard.pendingRequests,
                  label: 'Pending',
                  color: Colors.purple,
                ),"""

new_stat_cards = """                _StatCard(
                  icon: servicesIcon,
                  count: dashboard.totalServices,
                  label: servicesLabel,
                  color: Colors.blue,
                ),
                _StatCard(
                  icon: Icons.fact_check_outlined,
                  count: dashboard.activeServices,
                  label: 'Active',
                  color: Colors.green,
                ),
                _StatCard(
                  icon: Icons.hotel_class_outlined,
                  count: dashboard.inactiveServices,
                  label: 'Inactive',
                  color: Colors.orange,
                ),
                _StatCard(
                  icon: Icons.edit_note,
                  count: dashboard.draftServices,
                  label: 'Drafts',
                  color: Colors.grey,
                ),
                _StatCard(
                  icon: Icons.assignment_outlined,
                  count: dashboard.pendingBookings,
                  label: 'Pending',
                  color: Colors.purple,
                ),"""
content = content.replace(stat_cards, new_stat_cards)

# Also update the Quick Actions string
content = content.replace(
"""                  label: const Text(
                    'Add New Hotel',
                    style: TextStyle(""",
"""                  label: const Text(
                    'Add New Service',
                    style: TextStyle("""
)

with open(filepath, 'w') as f:
    f.write(content)
