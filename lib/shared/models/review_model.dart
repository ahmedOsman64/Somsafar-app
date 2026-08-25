class Review {
  final String id;
  final String serviceId;
  final String providerId;
  final String serviceTitle;
  final String travelerId;
  final String travelerName;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final String? providerReply;
  final DateTime? providerRepliedAt;

  Review({
    required this.id,
    required this.serviceId,
    required this.providerId,
    required this.serviceTitle,
    required this.travelerId,
    required this.travelerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.providerReply,
    this.providerRepliedAt,
  });

  Review copyWith({
    String? id,
    String? serviceId,
    String? providerId,
    String? serviceTitle,
    String? travelerId,
    String? travelerName,
    int? rating,
    String? comment,
    DateTime? createdAt,
    String? providerReply,
    DateTime? providerRepliedAt,
  }) {
    return Review(
      id: id ?? this.id,
      serviceId: serviceId ?? this.serviceId,
      providerId: providerId ?? this.providerId,
      serviceTitle: serviceTitle ?? this.serviceTitle,
      travelerId: travelerId ?? this.travelerId,
      travelerName: travelerName ?? this.travelerName,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      providerReply: providerReply ?? this.providerReply,
      providerRepliedAt: providerRepliedAt ?? this.providerRepliedAt,
    );
  }

  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      id: map['id'] ?? '',
      serviceId: map['service_id'] ?? '',
      providerId: map['provider_id'] ?? '',
      serviceTitle: map['service_title'] ?? 'Service',
      travelerId: map['traveler_id'] ?? '',
      travelerName: map['traveler_name'] ?? 'Guest',
      rating: map['rating'] ?? 5,
      comment: map['comment'] ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      providerReply: map['provider_reply'] as String?,
      providerRepliedAt: map['provider_replied_at'] != null
          ? DateTime.parse(map['provider_replied_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'service_id': serviceId,
      'provider_id': providerId,
      'service_title': serviceTitle,
      'traveler_id': travelerId,
      'traveler_name': travelerName,
      'rating': rating,
      'comment': comment,
      if (providerReply != null) 'provider_reply': providerReply,
      if (providerRepliedAt != null)
        'provider_replied_at': providerRepliedAt!.toIso8601String(),
    };
  }
}
