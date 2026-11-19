import '../data/models/market_models.dart';

class CandleService {
  List<Candle> build(List<PricePoint> points) {
    final map = <int, List<PricePoint>>{};
    for (final p in points) {
      final k = p.time.millisecondsSinceEpoch ~/ 900000;
      (map[k] ??= []).add(p);
    }
    final keys = map.keys.toList()..sort();
    return keys.map((k) {
      final xs = map[k]!..sort((a, b) => a.time.compareTo(b.time));
      final v = xs.map((e) => e.price).toList();
      return Candle(
          time: DateTime.fromMillisecondsSinceEpoch(k * 900000),
          open: v.first,
          high: v.reduce((a, b) => a > b ? a : b),
          low: v.reduce((a, b) => a < b ? a : b),
          close: v.last);
    }).toList();
  }
}
