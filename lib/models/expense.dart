import 'enums.dart';

/// A recurring annual expense. `healthcare` expenses grow at the plan's
/// healthcare inflation rate rather than general inflation.
class Expense {
  final String? id;
  final String name;
  final ExpenseCategory category;
  final double annualAmount;
  final double inflationRate;
  final int? startAge; // null = from retirement
  final int? endAge; // null = through end of plan

  const Expense({
    this.id,
    required this.name,
    required this.category,
    required this.annualAmount,
    this.inflationRate = 0.03,
    this.startAge,
    this.endAge,
  });

  bool activeAt(int age, {required int retirementAge}) {
    final start = startAge ?? retirementAge;
    return age >= start && (endAge == null || age <= endAge!);
  }

  Expense copyWith({
    String? id,
    String? name,
    ExpenseCategory? category,
    double? annualAmount,
    double? inflationRate,
    int? startAge,
    int? endAge,
  }) =>
      Expense(
        id: id ?? this.id,
        name: name ?? this.name,
        category: category ?? this.category,
        annualAmount: annualAmount ?? this.annualAmount,
        inflationRate: inflationRate ?? this.inflationRate,
        startAge: startAge ?? this.startAge,
        endAge: endAge ?? this.endAge,
      );

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String?,
        name: (j['name'] ?? '') as String,
        category: ExpenseCategoryX.fromDb((j['category'] ?? 'other') as String),
        annualAmount: (j['annual_amount'] as num?)?.toDouble() ?? 0,
        inflationRate: (j['inflation_rate'] as num?)?.toDouble() ?? 0.03,
        startAge: (j['start_age'] as num?)?.toInt(),
        endAge: (j['end_age'] as num?)?.toInt(),
      );

  Map<String, dynamic> toInsert(String userId) => {
        'user_id': userId,
        'name': name,
        'category': category.db,
        'annual_amount': annualAmount,
        'inflation_rate': inflationRate,
        'start_age': startAge,
        'end_age': endAge,
      };
}
