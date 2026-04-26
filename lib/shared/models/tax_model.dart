import 'user_model.dart';

enum TaxType { percentage, fixed }

class TaxModel {
  final String id;
  final String name;
  final ProviderType providerType;
  final TaxType taxType;
  final double rate;
  final bool isActive;
  final DateTime createdAt;

  TaxModel({
    required this.id,
    required this.name,
    required this.providerType,
    required this.taxType,
    required this.rate,
    required this.isActive,
    required this.createdAt,
  });

  factory TaxModel.fromJson(Map<String, dynamic> json) {
    return TaxModel(
      id: json['id'],
      name: json['name'],
      providerType: ProviderType.values.firstWhere(
        (e) =>
            e.name == json['provider_type'] || e.name == json['providerType'],
        orElse: () => ProviderType.all,
      ),
      taxType: TaxType.values.firstWhere(
        (e) => e.name == json['tax_type'] || e.name == json['taxType'],
        orElse: () => TaxType.percentage,
      ),
      rate: (json['rate'] as num).toDouble(),
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      createdAt:
          DateTime.tryParse(
            json['created_at']?.toString() ??
                json['createdAt']?.toString() ??
                '',
          ) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty && !id.startsWith('t_')) 'id': id,
      'name': name,
      'provider_type': providerType.name,
      'tax_type': taxType.name,
      'rate': rate,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  TaxModel copyWith({
    String? id,
    String? name,
    ProviderType? providerType,
    TaxType? taxType,
    double? rate,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return TaxModel(
      id: id ?? this.id,
      name: name ?? this.name,
      providerType: providerType ?? this.providerType,
      taxType: taxType ?? this.taxType,
      rate: rate ?? this.rate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
