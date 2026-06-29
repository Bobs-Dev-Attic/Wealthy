import 'enums.dart';

/// An asset/account the user holds. Balances drive projections; `type`
/// determines tax treatment on withdrawal and RMD eligibility.
class Account {
  final String? id;
  final String name;
  final AccountType type;
  final double balance;
  final double costBasis; // for taxable accounts: portion that is original basis
  final double expectedReturn;
  final double returnStdev;

  const Account({
    this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.costBasis = 0,
    this.expectedReturn = 0.06,
    this.returnStdev = 0.12,
  });

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    double? balance,
    double? costBasis,
    double? expectedReturn,
    double? returnStdev,
  }) =>
      Account(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        balance: balance ?? this.balance,
        costBasis: costBasis ?? this.costBasis,
        expectedReturn: expectedReturn ?? this.expectedReturn,
        returnStdev: returnStdev ?? this.returnStdev,
      );

  factory Account.fromJson(Map<String, dynamic> j) => Account(
        id: j['id'] as String?,
        name: (j['name'] ?? '') as String,
        type: AccountTypeX.fromDb((j['type'] ?? 'taxable') as String),
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
        costBasis: (j['cost_basis'] as num?)?.toDouble() ?? 0,
        expectedReturn: (j['expected_return'] as num?)?.toDouble() ?? 0.06,
        returnStdev: (j['return_stdev'] as num?)?.toDouble() ?? 0.12,
      );

  Map<String, dynamic> toInsert(String userId) => {
        'user_id': userId,
        'name': name,
        'type': type.db,
        'balance': balance,
        'cost_basis': costBasis,
        'expected_return': expectedReturn,
        'return_stdev': returnStdev,
      };
}
