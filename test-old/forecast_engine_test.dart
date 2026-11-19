import 'package:flutter_test/flutter_test.dart';
import 'package:goldpredict_ai/data/models/market_models.dart';
import 'package:goldpredict_ai/services/forecast_engine.dart';

void main() {
  test('produces 12h and 24h forecasts', () {
    final t = DateTime(2026, 1, 1);
    final cs = List.generate(120, (i) {
      final p = 7000 + i * .8 + (i % 7) * .2;
      return Candle(
          time: t.add(Duration(minutes: 15 * i)),
          open: p - .2,
          high: p + 1,
          low: p - 1,
          close: p);
    });
    final r = ForecastEngine().predict(cs);
    expect(r.length, 2);
    expect(r[0].hours, 12);
    expect(r[1].hours, 24);
    for (final f in r) {
      expect(f.low, greaterThanOrEqualTo(0));
      expect(f.high, greaterThan(f.low));
    }
  });
}
