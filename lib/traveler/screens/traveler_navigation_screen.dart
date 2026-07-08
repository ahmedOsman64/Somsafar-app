import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/localization_provider.dart';
import 'home_screen.dart';
import 'search/search_screen.dart';
import 'bookings_screen.dart';
import 'profile_screen.dart';

class TravelerNavigationScreen extends ConsumerStatefulWidget {
  const TravelerNavigationScreen({super.key});

  @override
  ConsumerState<TravelerNavigationScreen> createState() => _TravelerNavigationScreenState();
}

class _TravelerNavigationScreenState extends ConsumerState<TravelerNavigationScreen> {
  int _currentIndex = 0;

  // List of pages to be kept in memory using IndexedStack
  final List<Widget> _pages = const [
    TravelerHomeScreen(),
    TravelerSearchScreen(),
    TravelerBookingsScreen(),
    TravelerProfileScreen(),
  ];

  void _onItemTapped(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages.asMap().entries.map((entry) {
          final isSelected = _currentIndex == entry.key;
          return AnimatedOpacity(
            opacity: isSelected ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            child: entry.value,
          );
        }).toList(),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, loc.translate('home')),
                _buildNavItem(1, Icons.search_rounded, Icons.search_rounded, loc.translate('search')),
                _buildNavItem(2, Icons.calendar_today_rounded, Icons.calendar_today_outlined, loc.translate('bookings')),
                _buildNavItem(3, Icons.person_rounded, Icons.person_outline_rounded, loc.translate('profile')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData selectedIcon, IconData unselectedIcon, String label) {
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                isSelected ? selectedIcon : unselectedIcon,
                key: ValueKey<bool>(isSelected),
                color: AppColors.grey,
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
