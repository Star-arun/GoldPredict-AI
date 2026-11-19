import 'dart:math';
import '../data/models/market_models.dart';

class BacktestService {
  BacktestMetrics? evaluate(List<Candle> cs, {required int horizonBars}) {
    if (cs.length < horizonBars + 35) return null;
    final errors = <double>[], base = <double>[];
    var correct = 0, total = 0;
    final start = max(30, cs.length - 240);
    for (var i = start; i + horizonBars < cs.length; i += 4) {
      final origin = cs[i - 1].close, actual = cs[i + horizonBars].close;
      if (origin <= 0) continue;
      final v = cs.sublist(0, i).map((e) => e.close).toList(),
          tail = v.length > 32 ? v.sublist(v.length - 32) : v;
      final r = [
        for (var j = 1; j < tail.length; j++)
          if (tail[j - 1] != 0) tail[j] / tail[j - 1] - 1
      ];
      final avg = r.isEmpty ? 0.0 : r.reduce((a, b) => a + b) / r.length;
      final pred = origin * (1 + avg.clamp(-.00035, .00035) * horizonBars);
      errors.add((pred - actual).abs());
      base.add((origin - actual).abs());
      if (pred != origin && actual != origin) {
        total++;
        if ((pred - origin).sign == (actual - origin).sign) correct++;
      }
    }
    if (errors.isEmpty) return null;
    final mae = errors.reduce((a, b) => a + b) / errors.length,
        mse = errors.map((x) => x * x).reduce((a, b) => a + b) / errors.length;
    return BacktestMetrics(
        samples: errors.length,
        mae: mae,
        rmse: sqrt(mse),
        directionalAccuracy: total == 0 ? 0 : correct / total * 100,
        baselineMae: base.reduce((a, b) => a + b) / base.length);
  }
}
