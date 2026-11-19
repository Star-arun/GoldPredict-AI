import 'package:get/get.dart';
import 'package:goldpredict_ai/services/gold_price_calculator.dart';
import 'package:intl/intl.dart';
import '../../data/local/app_database.dart';
import '../../data/models/market_models.dart';
import '../../data/providers/market_data_provider.dart';
import '../../services/candle_service.dart';
import '../../services/indicator_service.dart';
import '../../services/forecast_engine.dart';
import '../../services/backtest_service.dart';

class DashboardController extends GetxController {
  final provider = Get.find<MarketDataProvider>(),
      candlesService = Get.find<CandleService>(),
      indicatorsService = Get.find<IndicatorService>(),
      engine = Get.find<ForecastEngine>(),
      backtester = Get.find<BacktestService>();
  final loading = false.obs, error = ''.obs, price = 0.0.obs;
  final updated = Rxn<DateTime>();
  final points = <PricePoint>[].obs,
      candles = <Candle>[].obs,
      forecasts = <ForecastResult>[].obs;
  final indicators = const Indicators().obs;
  final bt12 = Rxn<BacktestMetrics>(), bt24 = Rxn<BacktestMetrics>();
  final range = '24H'.obs;
  String get updatedText => updated.value == null
      ? 'Not refreshed'
      : DateFormat('dd MMM, hh:mm a').format(updated.value!);

  final tamilNaduPrice = 0.0.obs;
  final tamilNadu22K = 0.0.obs;
  final tamilNadu18K = 0.0.obs;

// Actual IBJA data only; not calculated from XAU.
  final ibjaPrice = 0.0.obs;
  @override
  void onInit() {
    super.onInit();
    loadLocal().then((_) => refresh());
  }

  Future<void> loadLocal() async {
    points.assignAll(await AppDatabase.instance.getPoints());
    candles.assignAll(await AppDatabase.instance.getCandles());
    if (points.isNotEmpty) price.value = points.last.price;
    calculate();
  }

  // @override
  // Future<void> refresh() async {
  //   if (loading.value) return;
  //   loading.value = true;
  //   error.value = '';
  //   try {
  //     final res =
  //         await Future.wait([provider.fetchSpot(), provider.fetchHistory()]);
  //     final quote = res[0] as double, history = res[1] as List<PricePoint>;
  //     if (history.isEmpty)
  //       throw Exception('No usable history returned by provider');
  //     final map = <int, PricePoint>{
  //       for (final p in points) p.time.millisecondsSinceEpoch: p,
  //       for (final p in history) p.time.millisecondsSinceEpoch: p
  //     };
  //     final now = DateTime.now();
  //     map[now.millisecondsSinceEpoch] = PricePoint(time: now, price: quote);
  //     final all = map.values.toList()..sort((a, b) => a.time.compareTo(b.time));
  //     await AppDatabase.instance.savePoints(all);
  //     final built = candlesService.build(all);
  //     await AppDatabase.instance.saveCandles(built);
  //     points.assignAll(all);
  //     candles.assignAll(built);
  //     price.value = quote;
  //     updated.value = now;
  //     calculate();
  //   } catch (e) {
  //     error.value = e.toString().replaceFirst('Exception: ', '');
  //   } finally {
  //     loading.value = false;
  //   }
  // }

  @override
  Future<void> refresh() async {
    if (loading.value) return;

    loading.value = true;
    error.value = '';

    try {
      // Step 1: Fetch current INR/gram spot price
      final quote = await provider.fetchSpot();

      // Step 2: Get USD/INR exchange rate
      final fx = provider.fxRate;

      if (fx == null || fx <= 0) {
        throw Exception('Invalid USD/INR exchange rate');
      }

      // Step 3: Fetch history and convert to INR/gram
      final history = await provider.fetchHistory(
        fxRate: fx,
      );

      if (history.isEmpty) {
        throw Exception('No usable history returned by provider');
      }

      final map = <int, PricePoint>{
        for (final p in points) p.time.millisecondsSinceEpoch: p,
        for (final p in history) p.time.millisecondsSinceEpoch: p,
      };

      final now = DateTime.now();

      map[now.millisecondsSinceEpoch] = PricePoint(time: now, price: quote);

      final all = map.values.toList()..sort((a, b) => a.time.compareTo(b.time));

      await AppDatabase.instance.savePoints(all);

      final built = candlesService.build(all);

      await AppDatabase.instance.saveCandles(built);

      points.assignAll(all);
      candles.assignAll(built);

      // International spot price INR/gram
      price.value = quote;

      // Tamil Nadu estimated price
      final prices = GoldPriceCalculator.calculateAllPrices(
        internationalInrPerGram: quote,
      );

      tamilNaduPrice.value = prices['24K']!;
      tamilNadu22K.value = prices['22K']!;
      tamilNadu18K.value = prices['18K']!;

      updated.value = now;

      calculate();
    } catch (e) {
      error.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      loading.value = false;
    }
  }

  void calculate() {
    indicators.value = indicatorsService.calculate(candles);
    forecasts.assignAll(engine.predict(candles));
    bt12.value = backtester.evaluate(candles, horizonBars: 48);
    bt24.value = backtester.evaluate(candles, horizonBars: 96);
  }

  List<PricePoint> get visiblePoints {
    if (points.isEmpty) return [];
    final d = switch (range.value) {
      '1H' => const Duration(hours: 1),
      '6H' => const Duration(hours: 6),
      '48H' => const Duration(hours: 48),
      _ => const Duration(hours: 24)
    };
    final cut = points.last.time.subtract(d);
    return points.where((p) => !p.time.isBefore(cut)).toList();
  }

  @override
  void onClose() {
    provider.dispose();
    super.onClose();
  }
}
