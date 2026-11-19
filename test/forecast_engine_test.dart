import 'package:flutter_test/flutter_test.dart';
import 'package:goldpredict_ai/data/models/market_models.dart';
import 'package:goldpredict_ai/services/backtest_service.dart';
import 'package:goldpredict_ai/services/forecast_engine.dart';

void main() {
  List<Candle> risingCandles(int count) {
    final start = DateTime(2026, 1, 1);
    return List.generate(count, (index) {
      final close = 7000 + index * 0.8 + (index % 7) * 0.2;
      return Candle(
        time: start.add(Duration(minutes: 15 * index)),
        open: close - 0.2,
        high: close + 1,
        low: close - 1,
        close: close,
      );
    });
  }

  test('produces separate upcoming 12h and 24h forecasts', () {
    final forecasts = ForecastEngine().predict(risingCandles(120));

    expect(forecasts.length, 2);
    expect(forecasts[0].hours, 12);
    expect(forecasts[1].hours, 24);
    for (final forecast in forecasts) {
      expect(forecast.low, greaterThanOrEqualTo(0));
      expect(forecast.high, greaterThan(forecast.low));
      expect(forecast.price, greaterThan(0));
    }
  });

  test('does not forecast with insufficient candle history', () {
    expect(ForecastEngine().predict(risingCandles(20)), isEmpty);
  });

  test('walk-forward backtest uses the forecast engine', () {
    final engine = ForecastEngine();
    final metrics = BacktestService().evaluate(
      risingCandles(190),
      horizonBars: 48,
      engine: engine,
    );

    expect(metrics, isNotNull);
    expect(metrics!.samples, greaterThan(0));
    expect(metrics.mae, greaterThanOrEqualTo(0));
    expect(metrics.directionalAccuracy, inInclusiveRange(0, 100));
  });
}
