import 'enums.dart';

/// A guaranteed (non-portfolio) income stream: Social Security, pension, etc.
class IncomeSource {
  final String? id;
  final String name;
  final IncomeType type;
  final double annualAmount;
  final int startAge;
  final int? endAge; // null = lifetime
  final double colaRate; // annual cost-of-living increase

  const IncomeSource({
    this.id,
    required this.name,
    required this.type,
    required this.annualAmount,
    this.startAge = 67,
    this.endAge,
    this.colaRate = 0.02,
  });

  bool activeAt(int age) => age >= startAge && (endAge == null || age <= endAge!);

  IncomeSource copyWith({
    String? id,
    String? name,
    IncomeType? type,
    double? annualAmount,
    int? startAge,
    int? endAge,
    double? colaRate,
  }) =>
      IncomeSource(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        annualAmount: annualAmount ?? this.annualAmount,
        startAge: startAge ?? this.startAge,
        endAge: endAge ?? this.endAge,
        colaRate: colaRate ?? this.colaRate,
      );

  factory IncomeSource.fromJson(Map<String, dynamic> j) => IncomeSource(
        id: j['id'] as String?,
        name: (j['name'] ?? '') as String,
        type: IncomeTypeX.fromDb((j['type'] ?? 'other') as String),
        annualAmount: (j['annual_amount'] as num?)?.toDouble() ?? 0,
        startAge: (j['start_age'] as num?)?.toInt() ?? 67,
        endAge: (j['end_age'] as num?)?.toInt(),
        colaRate: (j['cola_rate'] as num?)?.toDouble() ?? 0.02,
      );

  Map<String, dynamic> toInsert(String userId) => {
        'user_id': userId,
        'name': name,
        'type': type.db,
        'annual_amount': annualAmount,
        'start_age': startAge,
        'end_age': endAge,
        'cola_rate': colaRate,
      };
}
