import 'enums.dart';

/// An individual security position (stock / ETF / mutual fund) with a cached
/// recent price. Its market value rolls into the matching account-type bucket.
class Holding {
  final String? id;
  final String symbol;
  final String? name;
  final double shares;
  final AccountType accountType; // taxable / 401(k) / IRA / Roth / HSA
  final double costBasis;
  final double? lastPrice;
  final DateTime? lastPriceAt;

  const Holding({
    this.id,
    required this.symbol,
    this.name,
    required this.shares,
    this.accountType = AccountType.taxable,
    this.costBasis = 0,
    this.lastPrice,
    this.lastPriceAt,
  });

  double get marketValue => shares * (lastPrice ?? 0);

  /// Account types a holding can sit in (cash is excluded).
  static const investable = [
    AccountType.taxable,
    AccountType.traditional401k,
    AccountType.traditionalIra,
    AccountType.roth401k,
    AccountType.rothIra,
    AccountType.hsa,
  ];

  Holding copyWith({
    String? id,
    String? symbol,
    String? name,
    double? shares,
    AccountType? accountType,
    double? costBasis,
    double? lastPrice,
    DateTime? lastPriceAt,
  }) =>
      Holding(
        id: id ?? this.id,
        symbol: symbol ?? this.symbol,
        name: name ?? this.name,
        shares: shares ?? this.shares,
        accountType: accountType ?? this.accountType,
        costBasis: costBasis ?? this.costBasis,
        lastPrice: lastPrice ?? this.lastPrice,
        lastPriceAt: lastPriceAt ?? this.lastPriceAt,
      );

  factory Holding.fromJson(Map<String, dynamic> j) => Holding(
        id: j['id'] as String?,
        symbol: ((j['symbol'] ?? '') as String).toUpperCase(),
        name: j['name'] as String?,
        shares: (j['shares'] as num?)?.toDouble() ?? 0,
        accountType: AccountTypeX.fromDb((j['account_type'] ?? 'taxable') as String),
        costBasis: (j['cost_basis'] as num?)?.toDouble() ?? 0,
        lastPrice: (j['last_price'] as num?)?.toDouble(),
        lastPriceAt:
            j['last_price_at'] != null ? DateTime.tryParse(j['last_price_at'] as String) : null,
      );

  Map<String, dynamic> toInsert(String userId) => {
        'user_id': userId,
        'symbol': symbol.toUpperCase(),
        'name': name,
        'shares': shares,
        'account_type': accountType.db,
        'cost_basis': costBasis,
        'last_price': lastPrice,
        'last_price_at': lastPriceAt?.toIso8601String(),
      };
}
