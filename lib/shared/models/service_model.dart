import 'package:flutter/material.dart';

enum ServiceStatus { active, inactive, draft, pendingApproval, blocked }

class Service {
  final String id;
  final String providerId; // Owner of the service
  String title;
  String category;
  double price;
  String location;
  String description;
  ServiceStatus status;
  List<String> images;
  Map<String, dynamic> metadata;

  // Additional properties for search functionality
  double? rating;
  int? reviews;
  bool? isVerified;
  double? discount;
  List<String>? amenities;
  int? maxGuests;
  int? availableSlots;
  double? breakfastPrice;
  double? airportPickupPrice;
  double? extraBedPrice;
  double? cleaningPrice;
  double? earlyCheckInPrice;
  double? lateCheckoutPrice;
  double? adultPrice;
  double? childPrice;

  Service({
    required this.id,
    required this.providerId,
    required this.title,
    required this.category,
    required this.price,
    required this.location,
    required this.description,
    required this.status,
    required this.images,
    this.metadata = const {},
    this.rating,
    this.reviews,
    this.isVerified,
    this.discount,
    this.amenities,
    this.maxGuests,
    this.availableSlots,
    this.breakfastPrice,
    this.airportPickupPrice,
    this.extraBedPrice,
    this.cleaningPrice,
    this.earlyCheckInPrice,
    this.lateCheckoutPrice,
    this.adultPrice,
    this.childPrice,
  });

  Color get statusColor {
    switch (status) {
      case ServiceStatus.active:
        return const Color(0xFF27AE60);
      case ServiceStatus.inactive:
        return const Color(0xFF9CA3AF);
      case ServiceStatus.draft:
        return const Color(0xFFF2C94C);
      case ServiceStatus.pendingApproval:
        return const Color(0xFF2F80ED);
      case ServiceStatus.blocked:
        return const Color(0xFFEB5757);
    }
  }

  String get statusLabel {
    // Camel case specific handling
    if (status == ServiceStatus.pendingApproval) return 'Pending';
    return status.name[0].toUpperCase() + status.name.substring(1);
  }

  String get pricingType {
    if (metadata['pricing_type'] != null) return metadata['pricing_type'];
    final cat = category.toLowerCase();
    if (cat.contains('apartment')) return 'monthly';
    if (cat.contains('tour')) return 'daily';
    return 'nightly';
  }

  Service copyWith({
    String? id,
    String? providerId,
    String? title,
    String? category,
    double? price,
    String? location,
    String? description,
    ServiceStatus? status,
    List<String>? images,
    Map<String, dynamic>? metadata,
    double? rating,
    int? reviews,
    bool? isVerified,
    double? discount,
    List<String>? amenities,
    int? maxGuests,
    int? availableSlots,
    double? breakfastPrice,
    double? airportPickupPrice,
    double? extraBedPrice,
    double? cleaningPrice,
    double? earlyCheckInPrice,
    double? lateCheckoutPrice,
    double? adultPrice,
    double? childPrice,
  }) {
    return Service(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      title: title ?? this.title,
      category: category ?? this.category,
      price: price ?? this.price,
      location: location ?? this.location,
      description: description ?? this.description,
      status: status ?? this.status,
      images: images ?? this.images,
      metadata: metadata ?? this.metadata,
      rating: rating ?? this.rating,
      reviews: reviews ?? this.reviews,
      isVerified: isVerified ?? this.isVerified,
      discount: discount ?? this.discount,
      amenities: amenities ?? this.amenities,
      maxGuests: maxGuests ?? this.maxGuests,
      availableSlots: availableSlots ?? this.availableSlots,
      breakfastPrice: breakfastPrice ?? this.breakfastPrice,
      airportPickupPrice: airportPickupPrice ?? this.airportPickupPrice,
      extraBedPrice: extraBedPrice ?? this.extraBedPrice,
      cleaningPrice: cleaningPrice ?? this.cleaningPrice,
      earlyCheckInPrice: earlyCheckInPrice ?? this.earlyCheckInPrice,
      lateCheckoutPrice: lateCheckoutPrice ?? this.lateCheckoutPrice,
      adultPrice: adultPrice ?? this.adultPrice,
      childPrice: childPrice ?? this.childPrice,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'provider_id': providerId,
      'title': title,
      'category': category,
      'price': price,
      'location': location,
      'description': description,
      'status': status.name,
      'images': images,
      'metadata': {
        ...metadata,
        'cleaning_price': cleaningPrice,
        'early_check_in_price': earlyCheckInPrice,
        'late_check_out_price': lateCheckoutPrice,
        'adult_price': adultPrice,
        'child_price': childPrice,
        'max_guests': maxGuests,
      },
      'rating': rating,
      'reviews': reviews,
      'is_verified': isVerified,
      'discount': discount,
      'available_slots': availableSlots,
      'amenities': amenities,
      'breakfast_price': breakfastPrice,
      'airport_pickup_price': airportPickupPrice,
      'extra_bed_price': extraBedPrice,
      'cleaning_price': cleaningPrice,
      'early_check_in_price': earlyCheckInPrice,
      'late_check_out_price': lateCheckoutPrice,
    };
  }

  factory Service.fromJson(Map<String, dynamic> json) {
    // Robust parsing for amenities which might come as a String from Supabase (PgArray format)
    List<String>? parsedAmenities;
    if (json['amenities'] != null) {
      if (json['amenities'] is String) {
        parsedAmenities = (json['amenities'] as String)
            .replaceAll('{', '')
            .replaceAll('}', '')
            .split(',')
            .where((e) => e.trim().isNotEmpty)
            .map((e) => e.trim())
            .toList();
      } else {
        parsedAmenities = List<String>.from(json['amenities']);
      }
    }

    final metadata = Map<String, dynamic>.from(json['metadata'] ?? {});

    return Service(
      id: json['id'] ?? '',
      providerId: json['provider_id'] ?? '',
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      location: json['location'] ?? '',
      description: json['description'] ?? '',
      status: ServiceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ServiceStatus.draft,
      ),
      images: List<String>.from(json['images'] ?? []),
      metadata: metadata,
      rating: (json['rating'] as num?)?.toDouble(),
      reviews: (json['reviews'] as num?)?.toInt(),
      isVerified: json['is_verified'] as bool?,
      discount: (json['discount'] as num?)?.toDouble(),
      availableSlots: (json['available_slots'] as num?)?.toInt(),
      amenities: parsedAmenities,
      maxGuests: (json['max_guests'] as num?)?.toInt() ?? 
                  (metadata['max_guests'] as num?)?.toInt(),
      breakfastPrice: (json['breakfast_price'] as num?)?.toDouble() ?? 
                       (metadata['breakfast_price'] as num?)?.toDouble(),
      airportPickupPrice: (json['airport_pickup_price'] as num?)?.toDouble() ?? 
                          (metadata['airport_pickup_price'] as num?)?.toDouble(),
      extraBedPrice: (json['extra_bed_price'] as num?)?.toDouble() ?? 
                      (metadata['extra_bed_price'] as num?)?.toDouble(),
      cleaningPrice: (json['cleaning_price'] as num?)?.toDouble() ?? 
                     (metadata['cleaning_price'] as num?)?.toDouble(),
      earlyCheckInPrice: (json['early_check_in_price'] as num?)?.toDouble() ?? 
                         (metadata['early_check_in_price'] as num?)?.toDouble(),
      lateCheckoutPrice: (json['late_check_out_price'] as num?)?.toDouble() ?? 
                         (metadata['late_check_out_price'] as num?)?.toDouble(),
      adultPrice: (json['adult_price'] as num?)?.toDouble() ?? 
                   (metadata['adult_price'] as num?)?.toDouble(),
      childPrice: (json['child_price'] as num?)?.toDouble() ?? 
                   (metadata['child_price'] as num?)?.toDouble(),
    );
  }
}
