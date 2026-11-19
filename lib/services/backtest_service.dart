import 'dart:math';

import '../data/models/market_models.dart';
import 'forecast_engine.dart';

/// Chronological walk-forward evaluation. Each forecast only sees candles
/// available before its forecast origin.
class BacktestService {
  BacktestMetrics? evaluate(
    List<Candle> candles, {
    required int horizonBars,
    required ForecastEngine engine,
  }) {
    if (horizonBars <= 0 || candles.length < horizonBars + 36) return null;

    final errors = <double>[];
    final baselineErrors = <double>[];
    var correctDirections = 0;
    var directionalSamples = 0;

    // Use every fourth candle to reduce overlapping, highly correlated tests.
    const step = 4;
    const minimumTrainingBars = 32;
    const start = minimumTrainingBars;
    final lastOriginExclusive = candles.length - horizonBars;

    for (var end = start; end <= lastOriginExclusive; end += step) {
      final history = candles.sublist(0, end);
      final originPrice = history.last.close;
      final actualPrice = candles[end - 1 + horizonBars].close;
      if (originPrice <= 0 || actualPrice <= 0) continue;

      final hours = horizonBars ~/ ForecastEngine.barsPerHour;
      final forecast = engine.predictHorizon(history, hours);
      if (forecast == null) continue;

      final predictedChange = forecast.price - originPrice;
      final actualChange = actualPrice - originPrice;
      errors.add((forecast.price - actualPrice).abs());
      baselineErrors.add((originPrice - actualPrice).abs());

      if (actualChange.abs() > 0.000001 && predictedChange.abs() > 0.000001) {
        directionalSamples++;
        if (predictedChange.sign == actualChange.sign) {
          correctDirections++;
        }
      }
    }

    if (errors.isEmpty) return null;

    final mae = errors.reduce((a, b) => a + b) / errors.length;
    final mse =
        errors.map((e) => e * e).reduce((a, b) => a + b) / errors.length;
    final baselineMae =
        baselineErrors.reduce((a, b) => a + b) / baselineErrors.length;

    return BacktestMetrics(
      samples: errors.length,
      mae: mae,
      rmse: sqrt(mse),
      directionalAccuracy: directionalSamples == 0
          ? 0
          : correctDirections / directionalSamples * 100,
      baselineMae: baselineMae,
    );
  }
}
