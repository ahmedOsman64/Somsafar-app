import 'user_model.dart';

class TailorCustomer {
  final String id;
  final String name;
  final String phone;
  final Gender gender;
  final double shoulder; // Garab
  final double chest; // Xabad
  final double waist; // Dhex
  final double hips; // Miskaha
  final double sleeveLength; // Dhererka Gacanta
  final double overallLength; // Dhererka Guud
  final String notes;
  final DateTime updatedAt;

  TailorCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.gender,
    required this.shoulder,
    required this.chest,
    required this.waist,
    required this.hips,
    required this.sleeveLength,
    required this.overallLength,
    required this.notes,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'gender': gender.name,
        'shoulder': shoulder,
        'chest': chest,
        'waist': waist,
        'hips': hips,
        'sleeveLength': sleeveLength,
        'overallLength': overallLength,
        'notes': notes,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory TailorCustomer.fromJson(Map<String, dynamic> json) => TailorCustomer(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String? ?? '',
        gender: Gender.values.firstWhere((e) => e.name == json['gender'],
            orElse: () => Gender.male),
        shoulder: (json['shoulder'] as num?)?.toDouble() ?? 0.0,
        chest: (json['chest'] as num?)?.toDouble() ?? 0.0,
        waist: (json['waist'] as num?)?.toDouble() ?? 0.0,
        hips: (json['hips'] as num?)?.toDouble() ?? 0.0,
        sleeveLength: (json['sleeveLength'] as num?)?.toDouble() ?? 0.0,
        overallLength: (json['overallLength'] as num?)?.toDouble() ?? 0.0,
        notes: json['notes'] as String? ?? '',
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.now(),
      );

  TailorCustomer copyWith({
    String? id,
    String? name,
    String? phone,
    Gender? gender,
    double? shoulder,
    double? chest,
    double? waist,
    double? hips,
    double? sleeveLength,
    double? overallLength,
    String? notes,
    DateTime? updatedAt,
  }) =>
      TailorCustomer(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        gender: gender ?? this.gender,
        shoulder: shoulder ?? this.shoulder,
        chest: chest ?? this.chest,
        waist: waist ?? this.waist,
        hips: hips ?? this.hips,
        sleeveLength: sleeveLength ?? this.sleeveLength,
        overallLength: overallLength ?? this.overallLength,
        notes: notes ?? this.notes,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

enum TailorOrderStatus { received, sewing, ready, taken }

class TailorOrder {
  final String id;
  final String customerId;
  final String fabricType; // Nooca marada
  final String styleType; // Nooca tolista: Shaar, Dirac, Macawiis, iwm
  final DateTime dueDate;
  final TailorOrderStatus status;
  final double price;
  final double deposit;
  final String notes;
  final DateTime createdAt;

  TailorOrder({
    required this.id,
    required this.customerId,
    required this.fabricType,
    required this.styleType,
    required this.dueDate,
    required this.status,
    required this.price,
    required this.deposit,
    required this.notes,
    required this.createdAt,
  });

  double get balance => price - deposit;

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'fabricType': fabricType,
        'styleType': styleType,
        'dueDate': dueDate.toIso8601String(),
        'status': status.name,
        'price': price,
        'deposit': deposit,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TailorOrder.fromJson(Map<String, dynamic> json) => TailorOrder(
        id: json['id'] as String,
        customerId: json['customerId'] as String,
        fabricType: json['fabricType'] as String? ?? '',
        styleType: json['styleType'] as String? ?? '',
        dueDate: DateTime.parse(json['dueDate'] as String),
        status: TailorOrderStatus.values.firstWhere((e) => e.name == json['status'],
            orElse: () => TailorOrderStatus.received),
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        deposit: (json['deposit'] as num?)?.toDouble() ?? 0.0,
        notes: json['notes'] as String? ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );

  TailorOrder copyWith({
    String? id,
    String? customerId,
    String? fabricType,
    String? styleType,
    DateTime? dueDate,
    TailorOrderStatus? status,
    double? price,
    double? deposit,
    String? notes,
    DateTime? createdAt,
  }) =>
      TailorOrder(
        id: id ?? this.id,
        customerId: customerId ?? this.customerId,
        fabricType: fabricType ?? this.fabricType,
        styleType: styleType ?? this.styleType,
        dueDate: dueDate ?? this.dueDate,
        status: status ?? this.status,
        price: price ?? this.price,
        deposit: deposit ?? this.deposit,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
      );
}
