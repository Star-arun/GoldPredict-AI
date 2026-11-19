import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../data/local/app_database.dart';
import '../../data/models/market_models.dart';
import '../../data/providers/market_data_provider.dart';
import '../../services/backtest_service.dart';
import '../../services/candle_service.dart';
import '../../services/forecast_engine.dart';
import '../../services/indicator_service.dart';
import '../../services/gold_price_calculator.dart';

class DashboardController extends GetxController {
  final provider = Get.find<MarketDataProvider>();
  final candlesService = Get.find<CandleService>();
  final indicatorsService = Get.find<IndicatorService>();
  final engine = Get.find<ForecastEngine>();
  final backtester = Get.find<BacktestService>();

  final loading = false.obs;
  final error = ''.obs;
  final price = 0.0.obs;
  final tamilNaduPrice = 0.0.obs;
  final tamilNadu22K = 0.0.obs;
  final tamilNadu18K = 0.0.obs;
  final ibjaPrice = 0.0.obs;
  final updated = Rxn<DateTime>();
  final points = <PricePoint>[].obs;
  final candles = <Candle>[].obs;
  final forecasts = <ForecastResult>[].obs;
  final indicators = const Indicators().obs;
  final bt12 = Rxn<BacktestMetrics>();
  final bt24 = Rxn<BacktestMetrics>();
  final past12hChange = Rxn<double>();
  final past24hChange = Rxn<double>();
  final range = '24H'.obs;

  String get updatedText => updated.value == null
      ? 'Not refreshed'
      : DateFormat('dd MMM, hh:mm a').format(updated.value!);

  @override
  void onInit() {
    super.onInit();
    loadLocal().then((_) => refresh());
  }

  // Future<void> loadLocal() async {
  //   points.assignAll(await AppDatabase.instance.getPoints());
  //   candles.assignAll(await AppDatabase.instance.getCandles());
  //   if (points.isNotEmpty) price.value = points.last.price;
  //   calculate();
  // }

  Future<void> loadLocal() async {
    // Remove records older than 48 hours
    await AppDatabase.instance.deleteOlderThan48Hours();

    points.assignAll(await AppDatabase.instance.getPoints());
    candles.assignAll(await AppDatabase.instance.getCandles());

    if (points.isNotEmpty) {
      price.value = points.last.price;
    }

    calculate();
  }

  @override
  Future<void> refresh() async {
    if (loading.value) return;
    loading.value = true;
    error.value = '';
    try {
      // Fetch spot first because it provides the FX rate needed to convert
      // the history endpoint's USD/troy-ounce values into INR/gram.
      final quote = await provider.fetchSpot();
      final fxRate = provider.fxRate;
      if (fxRate == null || fxRate <= 0) {
        throw Exception('USD/INR exchange rate is unavailable');
      }
      final history = await provider.fetchHistory(fxRate: fxRate);
      if (history.isEmpty) {
        throw Exception('No usable history returned by provider');
      }

      final map = <int, PricePoint>{
        for (final point in points) point.time.millisecondsSinceEpoch: point,
        for (final point in history) point.time.millisecondsSinceEpoch: point,
      };
      final now = DateTime.now();
      map[now.millisecondsSinceEpoch] = PricePoint(time: now, price: quote);
      final all = map.values.toList()..sort((a, b) => a.time.compareTo(b.time));

      await AppDatabase.instance.savePoints(all);
      final built = candlesService.build(all);
      await AppDatabase.instance.saveCandles(built);

      points.assignAll(all);
      candles.assignAll(built);
      price.value = quote;
      updated.value = now;
      calculate();
    } catch (exception) {
      error.value = exception.toString().replaceFirst('Exception: ', '');
    } finally {
      loading.value = false;
    }
  }

  void calculate() {
    if (price.value > 0) {
      final estimated = GoldPriceCalculator.calculateAllPrices(
        internationalInrPerGram: price.value,
      );
      tamilNaduPrice.value = estimated['24K']!;
      tamilNadu22K.value = estimated['22K']!;
      tamilNadu18K.value = estimated['18K']!;
    }
    indicators.value = indicatorsService.calculate(candles);
    forecasts.assignAll(engine.predict(candles));
    bt12.value = backtester.evaluate(
      candles,
      horizonBars: 48,
      engine: engine,
    );
    bt24.value = backtester.evaluate(
      candles,
      horizonBars: 96,
      engine: engine,
    );
    past12hChange.value = _historicalChange(const Duration(hours: 12));
    past24hChange.value = _historicalChange(const Duration(hours: 24));
  }

  double? _historicalChange(Duration duration) {
    if (points.length < 2) return null;
    final latest = points.last;
    final cutoff = latest.time.subtract(duration);
    PricePoint? baseline;
    for (final point in points) {
      if (!point.time.isAfter(cutoff)) {
        baseline = point;
      } else {
        break;
      }
    }
    if (baseline == null || baseline.price <= 0) return null;
    return (latest.price / baseline.price - 1) * 100;
  }

  List<PricePoint> get visiblePoints {
    if (points.isEmpty) return [];
    final duration = switch (range.value) {
      '1H' => const Duration(hours: 1),
      '6H' => const Duration(hours: 6),
      '48H' => const Duration(hours: 48),
      _ => const Duration(hours: 24),
    };
    final cutoff = points.last.time.subtract(duration);
    return points.where((point) => !point.time.isBefore(cutoff)).toList();
  }

  @override
  void onClose() {
    provider.dispose();
    super.onClose();
  }
}
