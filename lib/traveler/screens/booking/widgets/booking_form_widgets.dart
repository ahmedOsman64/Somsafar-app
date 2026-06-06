import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/booking_forms_model.dart';
import '../../../../shared/widgets/app_network_image.dart';

// ─────────────────────────────────────────────
//  Custom Step Indicator
// ─────────────────────────────────────────────
class BookingStepIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep;
  final List<String> stepLabels;

  const BookingStepIndicator({
    required this.totalSteps,
    required this.currentStep,
    required this.stepLabels,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: List.generate(totalSteps * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector line
            final stepIndex = i ~/ 2;
            final isCompleted = stepIndex < currentStep;
            return Expanded(
              child: Container(
                height: 2,
                color: isCompleted
                    ? AppColors.secondary
                    : Colors.white.withValues(alpha: 0.3),
              ),
            );
          }
          final stepIndex = i ~/ 2;
          final isCompleted = stepIndex < currentStep;
          final isActive = stepIndex == currentStep;
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? AppColors.secondary
                      : isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.2),
                  border: isActive
                      ? Border.all(color: AppColors.secondary, width: 2)
                      : null,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text(
                          '${stepIndex + 1}',
                          style: TextStyle(
                            color: isActive ? AppColors.primary : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              if (stepIndex < stepLabels.length)
                Text(
                  stepLabels[stepIndex],
                  style: TextStyle(
                    color: isActive || isCompleted
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Section Header
// ─────────────────────────────────────────────
class BookingSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const BookingSectionHeader({
    required this.title,
    required this.icon,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Premium Date Picker Tile
// ─────────────────────────────────────────────
class DatePickerTile extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final IconData? icon;

  const DatePickerTile({
    required this.label,
    required this.value,
    this.onTap,
    this.icon = Icons.calendar_today,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasValue
              ? AppColors.primary.withValues(alpha: 0.05)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasValue
                ? AppColors.primary.withValues(alpha: 0.3)
                : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: hasValue ? AppColors.primary : Colors.grey[400],
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasValue ? value! : 'Select date',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: hasValue ? AppColors.primary : Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Counter Row
// ─────────────────────────────────────────────
class CounterRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final int value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final int minValue;
  final int? maxValue;

  const CounterRow({
    required this.label,
    this.subtitle,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    this.minValue = 1,
    this.maxValue,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final bool atMax = maxValue != null && value >= maxValue!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              _CounterButton(
                icon: Icons.remove,
                onTap: value > minValue ? onDecrement : null,
              ),
              Container(
                width: 44,
                alignment: Alignment.center,
                child: Text(
                  '$value',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              _CounterButton(
                icon: Icons.add,
                onTap: atMax ? null : onIncrement,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CounterButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap != null ? AppColors.primary : Colors.grey[200],
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap != null ? Colors.white : Colors.grey[400],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Info Banner
// ─────────────────────────────────────────────
class InfoBanner extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;

  const InfoBanner({
    required this.text,
    this.color = Colors.blue,
    this.icon = Icons.info_outline,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Premium Toggle Option
// ─────────────────────────────────────────────
class PremiumSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;

  const PremiumSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.icon = Icons.add_circle_outline,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: value
            ? AppColors.secondary.withValues(alpha: 0.07)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? AppColors.secondary.withValues(alpha: 0.4)
              : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: value ? AppColors.secondary : Colors.grey[400],
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Navigation Controls
// ─────────────────────────────────────────────
class BookingNavControls extends StatelessWidget {
  final bool isFirstStep;
  final bool isLastStep;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final String? nextLabel;

  const BookingNavControls({
    required this.isFirstStep,
    required this.isLastStep,
    required this.onBack,
    required this.onNext,
    this.nextLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (!isFirstStep)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (!isFirstStep) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: onNext,
                icon: Icon(
                  isLastStep ? Icons.payment : Icons.arrow_forward,
                  color: Colors.white,
                ),
                label: Text(
                  nextLabel ?? (isLastStep ? 'Proceed to Payment' : 'Continue'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Live Price Summary Card (bottom bar)
// ─────────────────────────────────────────────
class LivePriceSummaryBar extends StatelessWidget {
  final BookingSummary summary;

  const LivePriceSummaryBar({required this.summary, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _serviceLabel(summary.serviceType),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    if (summary.discount > 0) ...[
                      Text(
                        '\$${summary.subtotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 16,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      '\$${summary.totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      summary.serviceType == ServiceType.tour ? 'Person' : 'Total',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (summary.discount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Builder(
                    builder: (context) {
                      // discountLabel = short badge text e.g. "5% OFF"
                      // automaticDiscount = full label e.g. "Summer Sale — 5% OFF"
                      final label =
                          summary.extras['discountLabel']?.toString() ??
                          summary.extras['automaticDiscount']?.toString().split('—').last.trim() ??
                          '-\$${summary.discount.toStringAsFixed(0)} OFF';
                      return Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                'Taxes: \$${summary.taxes.toStringAsFixed(2)}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
              if (summary.extras.containsKey('platformFee'))
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Builder(
                    builder: (context) {
                      final isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
                      final feeKey = 'platformFee';
                      final feeText = isIOS
                          ? 'Fee included'
                          : 'Platform Fee: \$${_extractAmount(summary.extras[feeKey].toString())}';
                      return Text(
                        feeText,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _extractAmount(String text) {
    // Platform Fee (10.0%) : $10.00
    final parts = text.split('\$');
    return parts.length > 1 ? parts[1] : '0.00';
  }

  String _serviceLabel(ServiceType type) {
    switch (type) {
      case ServiceType.hotel:
        return '🏨 Hotel · Price per night';
      case ServiceType.apartment:
        return '🏢 Apartment · Price per month';
      case ServiceType.tour:
        return '🧭 Tour · Price per person';
      case ServiceType.vehicle:
        return '🚗 Vehicle · Per day';
    }
  }
}

// ─────────────────────────────────────────────
//  Error Banner
// ─────────────────────────────────────────────
class ErrorBanner extends StatelessWidget {
  final String message;

  const ErrorBanner({required this.message, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Service Image Gallery
// ─────────────────────────────────────────────
class ServiceImageGallery extends StatefulWidget {
  final List<String> images;
  const ServiceImageGallery({required this.images, super.key});

  @override
  State<ServiceImageGallery> createState() => _ServiceImageGalleryState();
}

class _ServiceImageGalleryState extends State<ServiceImageGallery> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _showFullScreenGallery(context, index),
                  child: AppNetworkImage(
                    imageUrl: widget.images[index],
                    fit: BoxFit.cover,
                    memCacheWidth: 800, // Optimize for gallery view
                    errorWidget: Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
          ),
          // Gradient Cover for top indicators
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Image Counter
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentIndex + 1}/${widget.images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Dots Indicator
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.images.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentIndex == index ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentIndex == index
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          // Navigation Arrows
          if (widget.images.length > 1) ...[
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _GalleryNavButton(
                  icon: Icons.chevron_left,
                  onTap: () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _GalleryNavButton(
                  icon: Icons.chevron_right,
                  onTap: () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFullScreenGallery(BuildContext context, int initialIndex) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) =>
          FullScreenGallery(images: widget.images, initialIndex: initialIndex),
    );
  }
}

class FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenGallery({
    required this.images,
    required this.initialIndex,
    super.key,
  });

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    widget.images[index],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
              );
            },
          ),
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ),
          // Counter
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GalleryNavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
