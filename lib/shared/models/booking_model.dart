import 'package:flutter/material.dart';

enum BookingStatus { pending, confirmed, completed, cancelled }

class Booking {
  final String id;
  final String serviceId;
  final String providerId; // Owner of the service being booked
  final String serviceTitle;
  final String travelerId;
  final String travelerName;
  final DateTime date; // Booking creation date or primary date
  final DateTime checkIn;
  final DateTime checkOut;
  final int guests;
  final int rooms;
  final double totalPrice;
  final double taxes;
  final String contactPhone;
  final String contactEmail;
  final String? specialRequests;
  final String? transactionId;
  final String? paymentMethod;
  final List<TravelerDetail> travelers;
  final Map<String, dynamic> metadata; // For package-specific details
  BookingStatus status;
  BookingPaymentStatus paymentStatus;
  final DateTime? confirmedAt;

  Booking({
    required this.id,
    required this.serviceId,
    required this.providerId,
    required this.serviceTitle,
    required this.travelerId,
    required this.travelerName,
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.rooms,
    required this.totalPrice,
    this.taxes = 0.0,
    required this.contactPhone,
    required this.contactEmail,
    this.specialRequests,
    this.transactionId,
    this.paymentMethod,
    this.travelers = const [],
    this.metadata = const {},
    required this.status,
    this.paymentStatus = BookingPaymentStatus.pending,
    this.confirmedAt,
  });

  Color get statusColor {
    switch (status) {
      case BookingStatus.confirmed:
        return const Color(0xFF27AE60); // Success
      case BookingStatus.completed:
        return const Color(0xFF2F80ED); // Info
      case BookingStatus.cancelled:
        return const Color(0xFFEB5757); // Error
      case BookingStatus.pending:
        return const Color(0xFFF2C94C); // Warning
    }
  }

  String get statusLabel =>
      status.name[0].toUpperCase() + status.name.substring(1);

  Booking copyWith({
    String? id,
    String? serviceId,
    String? providerId,
    String? serviceTitle,
    String? travelerId,
    String? travelerName,
    DateTime? date,
    DateTime? checkIn,
    DateTime? checkOut,
    int? guests,
    int? rooms,
    double? totalPrice,
    double? taxes,
    String? contactPhone,
    String? contactEmail,
    String? specialRequests,
    String? transactionId,
    String? paymentMethod,
    List<TravelerDetail>? travelers,
    Map<String, dynamic>? metadata,
    BookingStatus? status,
    BookingPaymentStatus? paymentStatus,
    DateTime? confirmedAt,
  }) {
    return Booking(
      id: id ?? this.id,
      serviceId: serviceId ?? this.serviceId,
      providerId: providerId ?? this.providerId,
      serviceTitle: serviceTitle ?? this.serviceTitle,
      travelerId: travelerId ?? this.travelerId,
      travelerName: travelerName ?? this.travelerName,
      date: date ?? this.date,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      guests: guests ?? this.guests,
      rooms: rooms ?? this.rooms,
      totalPrice: totalPrice ?? this.totalPrice,
      taxes: taxes ?? this.taxes,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      specialRequests: specialRequests ?? this.specialRequests,
      transactionId: transactionId ?? this.transactionId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      travelers: travelers ?? this.travelers,
      metadata: metadata ?? this.metadata,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      confirmedAt: confirmedAt ?? this.confirmedAt,
    );
  }
}

class TravelerDetail {
  final String? id;
  final String name;
  final int age;
  final String gender;
  final String? passport;

  TravelerDetail({
    this.id,
    required this.name,
    required this.age,
    required this.gender,
    this.passport,
  });

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'age': age,
        'gender': gender,
        if (passport != null) 'passport': passport,
      };

  factory TravelerDetail.fromJson(Map<String, dynamic> json) => TravelerDetail(
        id: json['id'] as String?,
        name: json['name'] as String? ?? '',
        age: (json['age'] as num?)?.toInt() ?? 0,
        gender: json['gender'] as String? ?? '',
        passport: json['passport'] as String?,
      );
}

enum BookingPaymentStatus { pending, paid, failed }
