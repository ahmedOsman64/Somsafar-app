

class Review {
  final String id;
  final String serviceId;
  final String providerId; // Added this
  final String serviceTitle;
  final String travelerId;
  final String travelerName;
  final int rating;
  final String comment;
  final DateTime createdAt;

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
  });

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
    };
  }
}
