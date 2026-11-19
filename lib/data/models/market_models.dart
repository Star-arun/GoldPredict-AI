class PricePoint {
  final DateTime time;
  final double price;
  const PricePoint({required this.time, required this.price});
}

class Candle {
  final DateTime time;
  final double open, high, low, close;
  const Candle(
      {required this.time,
      required this.open,
      required this.high,
      required this.low,
      required this.close});
  Map<String, Object?> toMap() => {
        'time': time.millisecondsSinceEpoch,
        'open': open,
        'high': high,
        'low': low,
        'close': close
      };
  factory Candle.fromMap(Map<String, Object?> m) => Candle(
      time: DateTime.fromMillisecondsSinceEpoch(m['time'] as int),
      open: (m['open'] as num).toDouble(),
      high: (m['high'] as num).toDouble(),
      low: (m['low'] as num).toDouble(),
      close: (m['close'] as num).toDouble());
}

class ForecastResult {
  final int hours;
  final double price, low, high, changePct, score;
  final String direction;
  const ForecastResult(
      {required this.hours,
      required this.price,
      required this.low,
      required this.high,
      required this.changePct,
      required this.score,
      required this.direction});
}

class Indicators {
  final double? ema12, ema26, rsi14, macd, atr14, volatility, momentum;
  const Indicators(
      {this.ema12,
      this.ema26,
      this.rsi14,
      this.macd,
      this.atr14,
      this.volatility,
      this.momentum});
}

class BacktestMetrics {
  final int samples;
  final double mae, rmse, directionalAccuracy, baselineMae;
  const BacktestMetrics(
      {required this.samples,
      required this.mae,
      required this.rmse,
      required this.directionalAccuracy,
      required this.baselineMae});
}
