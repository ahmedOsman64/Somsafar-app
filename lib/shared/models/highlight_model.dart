class TravelHighlight {
  final String id;
  final String title;
  final String location;
  final String description;
  final String imageUrl;
  final String tag;
  final int displayOrder;
  final bool isActive;

  const TravelHighlight({
    required this.id,
    required this.title,
    required this.location,
    required this.description,
    required this.imageUrl,
    required this.tag,
    this.displayOrder = 0,
    this.isActive = true,
  });

  TravelHighlight copyWith({
    String? title,
    String? location,
    String? description,
    String? imageUrl,
    String? tag,
    int? displayOrder,
    bool? isActive,
  }) {
    return TravelHighlight(
      id: id,
      title: title ?? this.title,
      location: location ?? this.location,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      tag: tag ?? this.tag,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'location': location,
      'description': description,
      'image_url': imageUrl,
      'tag': tag,
      'display_order': displayOrder,
      'active': isActive,
    };
  }

  factory TravelHighlight.fromMap(Map<String, dynamic> map) {
    return TravelHighlight(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      location: map['location'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['image_url'] ?? '',
      tag: map['tag'] ?? '',
      displayOrder: map['display_order'] ?? 0,
      isActive: map['active'] ?? true,
    );
  }
}
