class SpecialOffer {
  final String id;
  final String title;
  final String discount;
  final String description;
  final String imageUrl;
  final int order;
  final bool isActive;
  final String? linkedServiceId; // ID of service this offer applies to
  final double? discountPercent; // Numeric discount e.g. 20.0 = 20%

  const SpecialOffer({
    required this.id,
    required this.title,
    required this.discount,
    required this.description,
    required this.imageUrl,
    required this.order,
    this.isActive = true,
    this.linkedServiceId,
    this.discountPercent,
  });

  SpecialOffer copyWith({
    String? title,
    String? discount,
    String? description,
    String? imageUrl,
    int? order,
    bool? isActive,
    String? linkedServiceId,
    double? discountPercent,
  }) {
    return SpecialOffer(
      id: id,
      title: title ?? this.title,
      discount: discount ?? this.discount,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      linkedServiceId: linkedServiceId ?? this.linkedServiceId,
      discountPercent: discountPercent ?? this.discountPercent,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'discount': discount,
      'description': description,
      'imageUrl': imageUrl,
      'order': order,
      'isActive': isActive,
      'linkedServiceId': linkedServiceId,
      'discountPercent': discountPercent,
    };
  }

  factory SpecialOffer.fromMap(Map<String, dynamic> map) {
    return SpecialOffer(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      discount: map['discount'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      order: map['order'] ?? 0,
      isActive: map['isActive'] ?? true,
      linkedServiceId: map['linkedServiceId'] as String?,
      discountPercent: (map['discountPercent'] as num?)?.toDouble(),
    );
  }
}
