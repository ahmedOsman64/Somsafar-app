enum PaymentAccountType { bank, mobileMoney, card }

class PaymentAccount {
  final String id;
  final String providerName; // e.g. "Premier Bank", "Hormuud EVC Plus"
  final String accountNumber;
  final String holderName;
  final PaymentAccountType type;
  final bool isDefault;
  final bool isVerified;

  const PaymentAccount({
    required this.id,
    required this.providerName,
    required this.accountNumber,
    required this.holderName,
    required this.type,
    this.isDefault = false,
    this.isVerified = false,
  });

  PaymentAccount copyWith({
    String? providerName,
    String? accountNumber,
    String? holderName,
    PaymentAccountType? type,
    bool? isDefault,
    bool? isVerified,
  }) {
    return PaymentAccount(
      id: id,
      providerName: providerName ?? this.providerName,
      accountNumber: accountNumber ?? this.accountNumber,
      holderName: holderName ?? this.holderName,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'providerName': providerName,
    'accountNumber': accountNumber,
    'holderName': holderName,
    'type': type.name,
    'isDefault': isDefault,
    'isVerified': isVerified,
  };

  factory PaymentAccount.fromJson(Map<String, dynamic> json) => PaymentAccount(
    id: json['id'],
    providerName: json['providerName'],
    accountNumber: json['accountNumber'],
    holderName: json['holderName'],
    type: PaymentAccountType.values.byName(json['type']),
    isDefault: json['isDefault'] ?? false,
    isVerified: json['isVerified'] ?? false,
  );
}
