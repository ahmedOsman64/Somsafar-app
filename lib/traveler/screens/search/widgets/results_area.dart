import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'service_card.dart';
import 'search_states.dart';

class ResultsArea extends StatelessWidget {
  final List<dynamic> filteredServices;
  final bool isLoading;
  final bool isMobile;
  final bool isGridView;
  final String searchQuery;
  final String sortBy;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<bool> onViewToggled;
  final bool showMapView;
  final VoidCallback onMapToggled;
  final VoidCallback onClearFilters;
  final VoidCallback onExploreNearby;

  const ResultsArea({
    super.key,
    required this.filteredServices,
    required this.isLoading,
    required this.isMobile,
    required this.isGridView,
    required this.searchQuery,
    required this.sortBy,
    required this.onSortChanged,
    required this.onViewToggled,
    required this.showMapView,
    required this.onMapToggled,
    required this.onClearFilters,
    required this.onExploreNearby,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const LoadingState();
    }

    if (filteredServices.isEmpty) {
      return NoResultsState(
        onClearFilters: onClearFilters,
        onExploreNearby: onExploreNearby,
      );
    }

    return Column(
      children: [
        _buildResultsSummaryBar(context),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: isGridView
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      int crossAxisCount = isMobile ? 2 : 4;

                      if (!isMobile) {
                        if (showMapView) {
                          crossAxisCount = width < 600 ? 1 : 2;
                        } else {
                          if (width > 1200) {
                            crossAxisCount = 4;
                          } else if (width > 900) {
                            crossAxisCount = 3;
                          } else {
                            crossAxisCount = 2;
                          }
                        }
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.only(top: 16, bottom: 80),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: isMobile
                              ? 420
                              : (width > 1200
                                    ? 500
                                    : (width > 900 ? 480 : 470)),
                        ),
                        itemCount: filteredServices.length,
                        itemBuilder: (context, index) => ServiceCard(
                          service: filteredServices[index],
                          isGrid: true,
                        ),
                      );
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 16, bottom: 80),
                    itemCount: filteredServices.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ServiceCard(
                        service: filteredServices[index],
                        isGrid: false,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsSummaryBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${filteredServices.length} stays found${searchQuery.isNotEmpty ? ' in "$searchQuery"' : ''}',
              style: TextStyle(
                fontSize: MediaQuery.sizeOf(context).width > 600 ? 18 : 16,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 8),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Premium Grid/List Toggle
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToggleItem(
                      isActive: isGridView,
                      icon: Icons.grid_view_rounded,
                      onTap: () => onViewToggled(true),
                      tooltip: 'Grid view',
                    ),
                    const SizedBox(width: 4),
                    _buildToggleItem(
                      isActive: !isGridView,
                      icon: Icons.view_list_rounded,
                      onTap: () => onViewToggled(false),
                      tooltip: 'List view',
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Sort By Dropdown (desktop only)
              if (!isMobile)
                PopupMenuButton<String>(
                  initialValue: sortBy,
                  onSelected: onSortChanged,
                  tooltip: 'Sort results',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sort, size: 18),
                        const SizedBox(width: 6),
                        Text(sortBy, style: const TextStyle(fontSize: 14)),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ),
                  ),
                  itemBuilder: (context) =>
                      [
                            'Recommended',
                            'Price Low → High',
                            'Price High → Low',
                            'Rating',
                            'Distance',
                          ]
                          .map(
                            (sort) =>
                                PopupMenuItem(value: sort, child: Text(sort)),
                          )
                          .toList(),
                ),

              // Map Toggle — icon only on mobile, text+icon on desktop
              if (isMobile)
                IconButton(
                  onPressed: onMapToggled,
                  tooltip: showMapView ? 'Show List' : 'Show Map',
                  icon: Icon(
                    showMapView
                        ? Icons.format_list_bulleted
                        : Icons.map_outlined,
                    color: showMapView
                        ? AppColors.primary
                        : Colors.grey.shade600,
                  ),
                )
              else
                TextButton.icon(
                  onPressed: onMapToggled,
                  icon: Icon(
                    showMapView
                        ? Icons.format_list_bulleted
                        : Icons.map_outlined,
                    color: showMapView
                        ? AppColors.primary
                        : Colors.grey.shade600,
                  ),
                  label: Text(
                    showMapView ? 'Show List' : 'Show Map',
                    style: TextStyle(
                      color: showMapView
                          ? AppColors.primary
                          : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleItem({
    required bool isActive,
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38, // Slightly wider
          height: 32, // Fits in 40 height container with padding
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive ? AppColors.primary : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}
