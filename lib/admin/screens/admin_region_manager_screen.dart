import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/lookup_service.dart';
import '../../shared/services/service_repository.dart';
import '../../core/services/storage_service.dart';
import '../../shared/widgets/app_network_image.dart';

class AdminRegionManagerScreen extends ConsumerStatefulWidget {
  const AdminRegionManagerScreen({super.key});

  @override
  ConsumerState<AdminRegionManagerScreen> createState() => _AdminRegionManagerScreenState();
}

class _AdminRegionManagerScreenState extends ConsumerState<AdminRegionManagerScreen> {
  final ImagePicker _picker = ImagePicker();
  String? _processingKey;

  Future<void> _updateRegionImage(LookupItem region) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() => _processingKey = region.key);

      // Upload image to a dedicated 'regions' folder
      String? imageUrl;
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        imageUrl = await StorageService.uploadImage(image, folder: 'destinations', bytes: bytes);
      } else {
        imageUrl = await StorageService.uploadImage(image, folder: 'destinations');
      }

      if (imageUrl != null) {
        // Update all related keys to keep data in sync (synonyms)
        final List<String> keysToSync = [region.key.toLowerCase()];
        final String lowKey = region.key.toLowerCase();
        
        if (lowKey == 'banadir' || lowKey == 'banaadir') {
          keysToSync.add('banadir');
          keysToSync.add('banaadir');
        } else if (lowKey == 'hiran' || lowKey == 'hiiraan') {
          keysToSync.add('hiran');
          keysToSync.add('hiiraan');
        } else if (lowKey == 'bakol' || lowKey == 'bakool') {
          keysToSync.add('bakol');
          keysToSync.add('bakool');
        }
        
        // Remove duplicates and self
        final uniqueKeys = keysToSync.toSet().toList();
        
        for (final syncKey in uniqueKeys) {
          try {
            await LookupService.updateLookup('region', syncKey, {'icon': imageUrl});
          } catch (_) {
            // Ignore errors for the "other" key if it doesn't exist
          }
        }
        
        // Force refresh
        ref.invalidate(regionsProvider);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Success! Updated ${region.label} image.'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating region image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final regionsAsync = ref.watch(regionsProvider);
    final services = ref.watch(filteredServicesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: regionsAsync.when(
        data: (regions) {
          // Calculate service counts per region for the badges (with normalization)
          final Map<String, int> regionCounts = {};
          for (final s in services) {
            String reg = (s.metadata['region'] as String?)?.toLowerCase() ?? 
                        s.location.split(',').first.trim().toLowerCase();
            
            // Map synonyms to canonical key
            if (reg == 'banadir' || reg == 'mogadishu' || reg == 'muqdisho' || reg == 'xamar' || reg == 'hamar') {
              reg = 'banaadir';
            }
            if (reg == 'hiran') reg = 'hiiraan';
            if (reg == 'bakol') reg = 'bakool';
            
            regionCounts[reg] = (regionCounts[reg] ?? 0) + 1;
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(32.0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.map_rounded, color: AppColors.primary, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Destination Image Manager',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  'Curate the visual experience for travelers exploring the platform.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 350,
                    mainAxisSpacing: 32,
                    crossAxisSpacing: 32,
                    childAspectRatio: 0.75,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final region = regions[index];
                      final isProcessing = _processingKey == region.key;
                      
                      // Normalize slug for accurate service count checking
                      String slug = region.key.toLowerCase();
                      if (slug == 'banadir') slug = 'banaadir';
                      if (slug == 'hiran') slug = 'hiiraan';
                      if (slug == 'bakol') slug = 'bakool';
                      
                      final count = regionCounts[slug] ?? 0;
                      
                      return _PremiumRegionCard(
                        key: ValueKey('region_${region.key}'),
                        region: region,
                        serviceCount: count,
                        isProcessing: isProcessing,
                        onUpload: () => _updateRegionImage(region),
                      );
                    },
                    childCount: regions.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, stack) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _PremiumRegionCard extends StatefulWidget {
  final LookupItem region;
  final int serviceCount;
  final bool isProcessing;
  final VoidCallback onUpload;

  const _PremiumRegionCard({
    super.key,
    required this.region,
    required this.serviceCount,
    required this.isProcessing,
    required this.onUpload,
  });

  @override
  State<_PremiumRegionCard> createState() => _PremiumRegionCardState();
}

class _PremiumRegionCardState extends State<_PremiumRegionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.region.icon != null && 
        (widget.region.icon!.startsWith('http') || widget.region.icon!.startsWith('assets/'));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isHovered ? 0.08 : 0.03),
              blurRadius: _isHovered ? 20 : 10,
              offset: Offset(0, _isHovered ? 10 : 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Section
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (hasImage)
                      AnimatedScale(
                        scale: _isHovered ? 1.1 : 1.0,
                        duration: const Duration(milliseconds: 500),
                        child: widget.region.icon!.startsWith('assets/')
                            ? Image.asset(widget.region.icon!, fit: BoxFit.cover)
                            : AppNetworkImage(
                                imageUrl: '${StorageService.ensurePublicUrl(widget.region.icon!)}${widget.region.icon!.contains('?') ? '&' : '?'}t=${DateTime.now().millisecondsSinceEpoch}',
                                fit: BoxFit.cover,
                                memCacheWidth: 600, // Optimize for card view
                                errorWidget: Container(
                                  color: const Color(0xFFF1F5F9),
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.red),
                                        SizedBox(height: 8),
                                        Text('Image failed to load', style: TextStyle(fontSize: 10, color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                      )
                    else
                      Container(
                        color: const Color(0xFFF1F5F9),
                        child: Icon(Icons.image_outlined, 
                            size: 48, color: Colors.blueGrey[100]),
                      ),
                    
                    // Gradient Overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Badge - Service Count
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 4),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.business_center_rounded, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.serviceCount} Services',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.dark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (widget.isProcessing)
                      Container(
                        color: Colors.black45,
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),

              // Content Section
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.region.label,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Key: ${widget.region.key}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: widget.isProcessing ? null : widget.onUpload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_rounded, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Update Image',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
