import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
final _currencyCents = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
final _compact = NumberFormat.compactCurrency(symbol: '\$');
final _percent = NumberFormat.decimalPercentPattern(decimalDigits: 1);

String money(num value) => _currency.format(value);
String moneyCents(num value) => _currencyCents.format(value);
String moneyCompact(num value) => _compact.format(value);

/// Formats a fractional rate (0.04) as a percent string ("4.0%").
String percent(num rate) => _percent.format(rate);

/// Parses a user-typed percent ("4" or "4%") into a fraction (0.04).
double parsePercent(String input) {
  final cleaned = input.replaceAll('%', '').trim();
  final v = double.tryParse(cleaned) ?? 0;
  return v / 100.0;
}

/// Parses a user-typed money string ("$1,200" or "1200") into a double.
double parseMoney(String input) {
  final cleaned = input.replaceAll(RegExp(r'[^0-9.\-]'), '');
  return double.tryParse(cleaned) ?? 0;
}
