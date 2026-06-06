import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/special_offer_model.dart';
import '../../shared/services/special_offer_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_network_image.dart';

class AdminSpecialOffersScreen extends ConsumerStatefulWidget {
  const AdminSpecialOffersScreen({super.key});

  @override
  ConsumerState<AdminSpecialOffersScreen> createState() =>
      _AdminSpecialOffersScreenState();
}

class _AdminSpecialOffersScreenState
    extends ConsumerState<AdminSpecialOffersScreen> {
  void _viewOfferDetails(SpecialOffer offer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          top: 32,
          left: 32,
          right: 32,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Offer Details',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AppNetworkImage(
                  imageUrl: offer.imageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
              _buildDetailRow('Title', offer.title),
              const SizedBox(height: 16),
              _buildDetailRow('Discount', offer.discount),
              const SizedBox(height: 16),
              _buildDetailRow('Description', offer.description),
              if (offer.linkedServiceId != null) ...[
                const SizedBox(height: 16),
                _buildDetailRow('Linked Service ID', offer.linkedServiceId!),
                if (offer.discountPercent != null)
                  _buildDetailRow(
                    'System Discount',
                    '${offer.discountPercent}%',
                  ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final offers = ref.watch(specialOfferProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Special Offers'),
        centerTitle: true,
      ),
      body: offers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No special offers yet',
                    style: TextStyle(color: Colors.grey[600], fontSize: 18),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: offers.length,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final items = List<SpecialOffer>.from(offers);
                final item = items.removeAt(oldIndex);
                items.insert(newIndex, item);
                ref.read(specialOfferProvider.notifier).updateOrder(items);
              },
              itemBuilder: (context, index) {
                final offer = offers[index];
                return _OfferListTile(
                  key: ValueKey(offer.id),
                  offer: offer,
                  onView: () => _viewOfferDetails(offer),
                  onToggle: () async {
                    final error = await ref
                        .read(specialOfferProvider.notifier)
                        .toggleStatus(offer.id);
                    if (error != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed: $error'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                );
              },
            ),
    );
  }
}

class _OfferListTile extends StatelessWidget {
  final SpecialOffer offer;
  final VoidCallback onView;
  final VoidCallback onToggle;

  const _OfferListTile({
    super.key,
    required this.offer,
    required this.onView,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.drag_indicator, color: Colors.grey),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AppNetworkImage(
                imageUrl: offer.imageUrl,
                width: 80,
                height: 60,
                fit: BoxFit.cover,
                borderRadius: 8,
                memCacheWidth: 160, // Small preview
                errorWidget: Container(
                  width: 80,
                  height: 60,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${offer.discount} OFF',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    offer.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      color: offer.isActive ? Colors.green : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: offer.isActive,
              onChanged: (_) => onToggle(),
              activeThumbColor: AppColors.primary,
            ),
            IconButton(
              icon: const Icon(Icons.info_outline, color: AppColors.primary),
              onPressed: onView,
            ),
          ],
        ),
      ),
    );
  }
}
