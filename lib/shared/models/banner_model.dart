class BannerImage {
  final String id;
  final String imageUrl;
  final String? caption;
  final int order;
  final bool isActive;

  const BannerImage({
    required this.id,
    required this.imageUrl,
    this.caption,
    required this.order,
    this.isActive = true,
  });

  BannerImage copyWith({
    String? imageUrl,
    String? caption,
    int? order,
    bool? isActive,
  }) {
    return BannerImage(
      id: id,
      imageUrl: imageUrl ?? this.imageUrl,
      caption: caption ?? this.caption,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'image_url': imageUrl,
      'caption': caption,
      'display_order': order,
      'active': isActive,
    };
  }

  factory BannerImage.fromMap(Map<String, dynamic> map) {
    return BannerImage(
      id: map['id'] ?? '',
      imageUrl: map['image_url'] ?? '',
      caption: map['caption'],
      order: map['display_order'] ?? 0,
      isActive: map['active'] ?? true,
    );
  }
}
