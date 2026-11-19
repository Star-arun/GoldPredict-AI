import 'dart:math';

import '../data/models/market_models.dart';

/// Lightweight on-device statistical forecast for 15-minute candles.
/// This is not a trained machine-learning model and its signal strength is
/// not a calibrated probability.
class ForecastEngine {
  static const int candleMinutes = 15;
  static const int barsPerHour = 60 ~/ candleMinutes;

  List<ForecastResult> predict(List<Candle> candles) {
    if (candles.length < 32) return const [];

    return [12, 24]
        .map((hours) => _predictHorizon(candles, hours))
        .whereType<ForecastResult>()
        .toList();
  }

  /// Exposed so the walk-forward backtest can use exactly the same model.
  ForecastResult? predictHorizon(List<Candle> candles, int hours) {
    if (hours != 12 && hours != 24) return null;
    return _predictHorizon(candles, hours);
  }

  ForecastResult? _predictHorizon(List<Candle> candles, int hours) {
    if (candles.length < 32) return null;

    final closes = candles.map((c) => c.close).toList();
    final last = closes.last;
    if (!last.isFinite || last <= 0) return null;

    final logReturns = <double>[];
    for (var i = 1; i < closes.length; i++) {
      if (closes[i - 1] > 0 && closes[i] > 0) {
        logReturns.add(log(closes[i] / closes[i - 1]));
      }
    }
    if (logReturns.length < 24) return null;

    final recent4h = _tail(logReturns, 16);
    final recent12h = _tail(logReturns, 48);
    final recent24h = _tail(logReturns, 96);

    // Blend short-, medium- and longer-term drift. The damping reduces the
    // risk of extending a brief price spike linearly into a full-day forecast.
    final driftPerBar = (_mean(recent4h) * 0.50 +
            _mean(recent12h) * 0.30 +
            _mean(recent24h) * 0.20) *
        0.55;

    final emaFast = _ema(closes, 16);
    final emaSlow = _ema(closes, 48);
    final trendPerBar = emaFast == null || emaSlow == null
        ? 0.0
        : (log(emaFast / emaSlow) / 48) * 0.20;

    final momentum4h =
        closes.length > 16 ? log(last / closes[closes.length - 17]) / 16 : 0.0;
    final momentum12h =
        closes.length > 48 ? log(last / closes[closes.length - 49]) / 48 : 0.0;
    final momentumPerBar = (momentum4h * 0.65 + momentum12h * 0.35) * 0.15;

    // Clamp extreme extrapolation. This is a guardrail, not a price limit.
    final expectedLogReturnPerBar = (driftPerBar + trendPerBar + momentumPerBar)
        .clamp(-0.00020, 0.00020)
        .toDouble();
    final horizonBars = hours * barsPerHour;
    final expectedLogReturn = expectedLogReturnPerBar * horizonBars;
    final predictedPrice = last * exp(expectedLogReturn);
    final changePct = (exp(expectedLogReturn) - 1) * 100;

    final volatility = _standardDeviation(recent24h);
    final range = last * volatility * sqrt(horizonBars) * 1.28;
    final direction = changePct > 0.05
        ? 'Bullish'
        : changePct < -0.05
            ? 'Bearish'
            : 'Neutral';

    // Heuristic directional strength only; do not present this as probability.
    final expectedMoveInVolUnits = volatility <= 0
        ? 0.0
        : expectedLogReturn.abs() / (volatility * sqrt(horizonBars));
    final signalStrength =
        (50 + expectedMoveInVolUnits * 18).clamp(50, 75).toDouble();

    return ForecastResult(
      hours: hours,
      price: predictedPrice,
      low: max(0.0, predictedPrice - range),
      high: predictedPrice + range,
      changePct: changePct,
      score: signalStrength,
      direction: direction,
    );
  }

  List<double> _tail(List<double> values, int count) =>
      values.length <= count ? values : values.sublist(values.length - count);

  double _mean(List<double> values) =>
      values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;

  double _standardDeviation(List<double> values) {
    if (values.length < 2) return 0.0;
    final mean = _mean(values);
    final variance = values
            .map((value) => pow(value - mean, 2).toDouble())
            .reduce((a, b) => a + b) /
        (values.length - 1);
    return sqrt(variance);
  }

  double? _ema(List<double> values, int period) {
    if (values.length < period) return null;
    final multiplier = 2 / (period + 1);
    var result = values.take(period).reduce((a, b) => a + b) / period;
    for (final value in values.skip(period)) {
      result = value * multiplier + result * (1 - multiplier);
    }
    return result;
  }
}
