class WalletEntity {
  const WalletEntity({
    required this.id,
    required this.name,
    required this.balance,
    this.reservedForSavings = 0,
    this.icon,
    this.iconColor,
    this.isHighlighted = false,
  });

  final String id;
  final String name;
  final double balance;
  final double reservedForSavings;
  final String? icon;
  final String? iconColor;
  final bool isHighlighted;

  WalletEntity copyWith({
    String? id,
    String? name,
    double? balance,
    double? reservedForSavings,
    String? icon,
    String? iconColor,
    bool? isHighlighted,
  }) {
    return WalletEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      reservedForSavings: reservedForSavings ?? this.reservedForSavings,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
      isHighlighted: isHighlighted ?? this.isHighlighted,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'balance': balance,
      'reservedForSavings': reservedForSavings,
      'icon': icon,
      'iconColor': iconColor,
      'isHighlighted': isHighlighted,
    };
  }

  factory WalletEntity.fromMap(Map<String, dynamic> map) {
    return WalletEntity(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      balance: (map['balance'] as num?)?.toDouble() ?? 0,
      reservedForSavings: (map['reservedForSavings'] as num?)?.toDouble() ?? 0,
      icon: map['icon'] as String?,
      iconColor: map['iconColor'] as String?,
      isHighlighted: map['isHighlighted'] as bool? ?? false,
    );
  }
}
