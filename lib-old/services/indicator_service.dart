import 'dart:math';
import '../data/models/market_models.dart';

class IndicatorService {
  Indicators calculate(List<Candle> cs) {
    final v = cs.map((e) => e.close).toList();
    if (v.length < 2) return const Indicators();
    final a = _ema(v, 12), b = _ema(v, 26), r = _rsi(v, 14), atr = _atr(cs, 14);
    final rets = [
      for (var i = 1; i < v.length; i++)
        if (v[i - 1] != 0) v[i] / v[i - 1] - 1
    ];
    double? vol;
    if (rets.length > 1) {
      final m = rets.reduce((x, y) => x + y) / rets.length;
      final variance =
          rets.map((x) => pow(x - m, 2).toDouble()).reduce((x, y) => x + y) /
              (rets.length - 1);
      vol = sqrt(variance) * sqrt(96) * 100;
    }
    final mom = v.length > 4 ? (v.last / v[v.length - 5] - 1) * 100 : null;
    return Indicators(
        ema12: a,
        ema26: b,
        rsi14: r,
        macd: a != null && b != null ? a - b : null,
        atr14: atr,
        volatility: vol,
        momentum: mom);
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

  double? _rsi(List<double> v, int n) {
    if (v.length <= n) return null;
    var g = 0.0, l = 0.0;
    for (var i = 1; i <= n; i++) {
      final d = v[i] - v[i - 1];
      if (d >= 0)
        g += d;
      else
        l -= d;
    }
    var ag = g / n, al = l / n;
    for (var i = n + 1; i < v.length; i++) {
      final d = v[i] - v[i - 1];
      ag = (ag * (n - 1) + (d > 0 ? d : 0)) / n;
      al = (al * (n - 1) + (d < 0 ? -d : 0)) / n;
    }
    if (al == 0) return 100;
    final rs = ag / al;
    return 100 - 100 / (1 + rs);
  }

  double? _atr(List<Candle> v, int n) {
    if (v.length < n + 1) return null;
    final tr = <double>[];
    for (var i = 1; i < v.length; i++) {
      final c = v[i], p = v[i - 1];
      tr.add([c.high - c.low, (c.high - p.close).abs(), (c.low - p.close).abs()]
          .reduce((a, b) => a > b ? a : b));
    }
    final s = tr.skip(max(0, tr.length - n));
    return s.reduce((a, b) => a + b) / s.length;
  }
}
