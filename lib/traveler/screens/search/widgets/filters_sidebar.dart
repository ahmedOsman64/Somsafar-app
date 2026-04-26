import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class FiltersSidebar extends StatelessWidget {
  final RangeValues priceRange;
  final ValueChanged<RangeValues> onPriceRangeChanged;
  final List<String> selectedPropertyTypes;
  final ValueChanged<String> onPropertyTypeToggled;
  final List<String> selectedAmenities;
  final ValueChanged<String> onAmenityToggled;
  final bool verifiedOnly;
  final ValueChanged<bool> onVerifiedOnlyChanged;
  final VoidCallback onReset;
  final VoidCallback onApply;
  final VoidCallback? onClose;

  const FiltersSidebar({
    super.key,
    required this.priceRange,
    required this.onPriceRangeChanged,
    required this.selectedPropertyTypes,
    required this.onPropertyTypeToggled,
    required this.selectedAmenities,
    required this.onAmenityToggled,
    required this.verifiedOnly,
    required this.onVerifiedOnlyChanged,
    required this.onReset,
    required this.onApply,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onReset,
                      icon: const Icon(Icons.restart_alt, size: 20),
                      label: const Text(
                        'Reset',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                      ),
                    ),
                    if (onClose != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: onClose,
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: 'Close Filters',
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const Divider(height: 32),

            // Price Range
            _buildFilterSection('Price Range', [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RangeSlider(
                    values: priceRange,
                    min: 0,
                    max: 500,
                    divisions: 10,
                    activeColor: const Color(
                      0xFF0D3B66,
                    ), // Match image's dark blue
                    inactiveColor: const Color(
                      0xFF0D3B66,
                    ).withValues(alpha: 0.1),
                    labels: RangeLabels(
                      '\$${priceRange.start.toInt()}',
                      '\$${priceRange.end.toInt()}',
                    ),
                    onChanged: onPriceRangeChanged,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${priceRange.start.toInt()}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '\$${priceRange.end.toInt()}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ]),

            const SizedBox(height: 24),

            // Property Type
            _buildFilterSection('Property Type', [
              _buildCheckbox(
                'Hotel',
                'Hotel',
                selectedPropertyTypes.contains('Hotel'),
                (val) => onPropertyTypeToggled('Hotel'),
              ),
              _buildCheckbox(
                'Apartment',
                'Apartment',
                selectedPropertyTypes.contains('Apartment'),
                (val) => onPropertyTypeToggled('Apartment'),
              ),
              _buildCheckbox(
                'Tour',
                'Tour',
                selectedPropertyTypes.contains('Tour'),
                (val) => onPropertyTypeToggled('Tour'),
              ),
            ]),

            const SizedBox(height: 24),

            // Amenities
            _buildFilterSection('Amenities', [
              _buildCheckbox(
                'WiFi',
                'WiFi',
                selectedAmenities.contains('WiFi'),
                (val) => onAmenityToggled('WiFi'),
              ),
              _buildCheckbox(
                'AC',
                'AC',
                selectedAmenities.contains('AC'),
                (val) => onAmenityToggled('AC'),
              ),
              _buildCheckbox(
                'Pool',
                'Pool',
                selectedAmenities.contains('Pool'),
                (val) => onAmenityToggled('Pool'),
              ),
              _buildCheckbox(
                'Parking',
                'Parking',
                selectedAmenities.contains('Parking'),
                (val) => onAmenityToggled('Parking'),
              ),
              _buildCheckbox(
                'Breakfast',
                'Breakfast',
                selectedAmenities.contains('Breakfast'),
                (val) => onAmenityToggled('Breakfast'),
              ),
              _buildCheckbox(
                'Airport Shuttle',
                'Airport Shuttle',
                selectedAmenities.contains('Airport Shuttle'),
                (val) => onAmenityToggled('Airport Shuttle'),
              ),
              _buildCheckbox(
                'Gym',
                'Gym',
                selectedAmenities.contains('Gym'),
                (val) => onAmenityToggled('Gym'),
              ),
              _buildCheckbox(
                'Spa',
                'Spa',
                selectedAmenities.contains('Spa'),
                (val) => onAmenityToggled('Spa'),
              ),
              _buildCheckbox(
                'Restaurant',
                'Restaurant',
                selectedAmenities.contains('Restaurant'),
                (val) => onAmenityToggled('Restaurant'),
              ),
              _buildCheckbox(
                'TV',
                'TV',
                selectedAmenities.contains('TV'),
                (val) => onAmenityToggled('TV'),
              ),
              _buildCheckbox(
                'Coffee Machine',
                'Coffee Machine',
                selectedAmenities.contains('Coffee Machine'),
                (val) => onAmenityToggled('Coffee Machine'),
              ),
              _buildCheckbox(
                'Safe',
                'Safe',
                selectedAmenities.contains('Safe'),
                (val) => onAmenityToggled('Safe'),
              ),
            ]),

            const SizedBox(height: 24),

            // Verified Only
            _buildFilterSection('', [
              SwitchListTile(
                title: const Text(
                  'Verified Only',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                value: verifiedOnly,
                activeThumbColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: onVerifiedOnlyChanged,
              ),
            ]),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                if (onClose != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onClose,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onApply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Apply Filters',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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

  Widget _buildFilterSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
        ],
        ...children,
      ],
    );
  }

  Widget _buildCheckbox(
    String label,
    String value,
    bool isChecked,
    ValueChanged<bool?> onChanged,
  ) {
    return CheckboxListTile(
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: isChecked,
      activeColor: AppColors.primary,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
