import 'package:flutter/material.dart';

enum DiscountStatus { active, scheduled, ended }

class Discount {
  final String id;
  final String providerId;
  final double value;
  final bool isPercentage;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> applicableServiceIds;
  final DiscountStatus status;
  final String code;
  final DateTime createdAt;

  Discount({
    required this.id,
    required this.providerId,
    required this.value,
    required this.isPercentage,
    required this.startDate,
    required this.endDate,
    required this.applicableServiceIds,
    required this.status,
    this.code = '',
    required this.createdAt,
  });

  factory Discount.fromJson(Map<String, dynamic> json) {
    return Discount(
      id: json['id'] as String,
      providerId: json['provider_id'] as String,
      value: (json['value'] as num).toDouble(),
      isPercentage: json['is_percentage'] as bool,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      applicableServiceIds: List<String>.from(
        json['applicable_service_ids'] ?? [],
      ),
      status: DiscountStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String),
        orElse: () => DiscountStatus.active,
      ),
      code: json['code'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'provider_id': providerId,
      'value': value,
      'is_percentage': isPercentage,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'applicable_service_ids': applicableServiceIds,
      'status': status.name,
      'code': code,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Color get statusColor {
    switch (status) {
      case DiscountStatus.active:
        return Colors.green;
      case DiscountStatus.scheduled:
        return Colors.blue;
      case DiscountStatus.ended:
        return Colors.grey;
    }
  }

  String get discountText {
    return isPercentage
        ? '${value.toInt()}% OFF'
        : '\$${value.toInt()} OFF';
  }

  /// Short badge label shown on cards (just the value, not the title)
  String get badgeText {
    if (isPercentage) return '${value.toInt()}% OFF';
    return '\$${value.toInt()} OFF';
  }

  String get expiryText {
    final now = DateTime.now();
    if (status == DiscountStatus.ended) {
      final diff = now.difference(endDate).inDays;
      return 'Expired $diff days ago';
    } else if (status == DiscountStatus.scheduled) {
      final diff = startDate.difference(now).inDays;
      return 'Starts in $diff days';
    } else {
      final diff = endDate.difference(now).inDays;
      if (diff < 1) {
        return 'Ends today';
      }
      return 'Ends in $diff days';
    }
  }
}
