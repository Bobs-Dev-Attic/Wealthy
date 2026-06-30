/// Per-symbol outcome of a price lookup, used to show diagnostics in the UI.
class QuoteDetail {
  final String symbol;
  final double? price;
  final String? source; // 'yahoo' | 'stooq' | null
  final String status; // 'ok' | 'not found' | 'error: ...'
  const QuoteDetail({required this.symbol, this.price, this.source, required this.status});

  bool get ok => price != null;

  factory QuoteDetail.fromJson(Map<String, dynamic> j) => QuoteDetail(
        symbol: (j['symbol'] ?? '').toString().toUpperCase(),
        price: (j['price'] as num?)?.toDouble(),
        source: j['source'] as String?,
        status: (j['status'] ?? '').toString(),
      );
}

/// The full result of a quotes API call: the price map the app applies plus
/// rich diagnostics (per-symbol detail, HTTP status, any error message).
class QuoteResult {
  final Map<String, double> prices;
  final List<QuoteDetail> details;
  final List<String> requested;
  final String? error;
  final int? httpStatus;

  const QuoteResult({
    this.prices = const {},
    this.details = const [],
    this.requested = const [],
    this.error,
    this.httpStatus,
  });

  int get pricedCount => details.where((d) => d.ok).length;
}
