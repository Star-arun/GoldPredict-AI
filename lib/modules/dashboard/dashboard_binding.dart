import 'package:get/get.dart';
import '../../data/providers/market_data_provider.dart';
import '../../services/candle_service.dart';
import '../../services/indicator_service.dart';
import '../../services/forecast_engine.dart';
import '../../services/backtest_service.dart';
import 'dashboard_controller.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(MarketDataProvider(), permanent: true);
    Get.put(CandleService(), permanent: true);
    Get.put(IndicatorService(), permanent: true);
    Get.put(ForecastEngine(), permanent: true);
    Get.put(BacktestService(), permanent: true);
    Get.put(DashboardController(), permanent: true);
  }
}
