import 'dart:math';
import '../data/models/market_models.dart';

class ForecastEngine {
  List<ForecastResult> predict(List<Candle> cs) {
    if (cs.length < 12) return [];
    final v = cs.map((e) => e.close).toList(), last = v.last;
    final r = [
      for (var i = 1; i < v.length; i++)
        if (v[i - 1] > 0) v[i] / v[i - 1] - 1
    ];
    final tail = r.length > 32 ? r.sublist(r.length - 32) : r;
    final mean =
        tail.isEmpty ? 0.0 : tail.reduce((a, b) => a + b) / tail.length;
    final variance = tail.length < 2
        ? 1e-6
        : tail.map((x) => pow(x - mean, 2).toDouble()).reduce((a, b) => a + b) /
            (tail.length - 1);
    final drift = (mean * 4).clamp(-.0015, .0015).toDouble();
    final fast = _ema(v, 8), slow = _ema(v, 24);
    final trend = fast != null && slow != null
        ? ((fast - slow) / last).clamp(-.002, .002).toDouble()
        : 0.0;
    final mom = v.length > 8
        ? ((last / v[v.length - 9] - 1).clamp(-.004, .004)).toDouble()
        : 0.0;
    final hourly = drift * .35 + trend * .4 / 6 + mom * .25 / 8,
        sigma = sqrt(variance) * 2;
    return [12, 24].map((h) {
      final p = last * (1 + hourly * h),
          band = last * sigma * sqrt(h) * 1.65,
          pct = (p / last - 1) * 100,
          score =
              (50 + hourly.abs() / (sigma + 1e-5) * 8).clamp(50, 78).toDouble();
      return ForecastResult(
          hours: h,
          price: p,
          low: max(0, p - band),
          high: p + band,
          changePct: pct,
          score: score,
          direction: pct > .03
              ? 'Bullish'
              : pct < -.03
                  ? 'Bearish'
                  : 'Neutral');
    }).toList();
  }

  double? _ema(List<double> v, int n) {
    if (v.length < n) return null;
    final k = 2 / (n + 1);
    var x = v.take(n).reduce((a, b) => a + b) / n;
    for (final y in v.skip(n)) {
      x = y * k + x * (1 - k);
    }
    return x;
  }
}
