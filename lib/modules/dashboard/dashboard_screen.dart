import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../data/models/market_models.dart';
import 'dashboard_controller.dart';

class DashboardScreen extends GetView<DashboardController> {
  const DashboardScreen({super.key});
  static const gold = Color(0xFFB88932), ink = Color(0xFF262626);
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const Row(children: [
            Icon(Icons.auto_graph, color: gold),
            SizedBox(width: 8),
            Text('GoldPredict AI',
                style: TextStyle(fontWeight: FontWeight.w800))
          ]),
          actions: [
            Obx(() => IconButton(
                onPressed: controller.loading.value ? null : controller.refresh,
                icon: controller.loading.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh)))
          ]),
      body: Obx(() => RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            _price(),
            if (controller.error.value.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _error(controller.error.value)),
            const SizedBox(height: 18),
            _heading('Past market movement',
                'Actual price change over completed periods • INR per gram'),
            const SizedBox(height: 10),
            _pastMovement(),
            const SizedBox(height: 10),
            _chart(),
            const SizedBox(height: 18),
            _heading('Future gold price prediction',
                'Experimental on-device estimate • upcoming 12H / 24H'),
            const SizedBox(height: 10),
            if (controller.forecasts.isEmpty)
              _empty(
                  'Forecast needs at least 32 fifteen-minute candles (about 8 hours of history).')
            else
              Row(
                  children: controller.forecasts
                      .map((f) => Expanded(
                          child: Padding(
                              padding:
                                  EdgeInsets.only(right: f.hours == 12 ? 9 : 0),
                              child: _forecast(f))))
                      .toList()),
            const SizedBox(height: 18),
            _heading('Technical indicators',
                'Calculated from locally stored candles'),
            const SizedBox(height: 10),
            _indicatorGrid(controller.indicators.value),
            const SizedBox(height: 18),
            _heading('Walk-forward backtest',
                'Historical evaluation, not a guarantee'),
            const SizedBox(height: 10),
            _test('12-hour horizon', controller.bt12.value),
            const SizedBox(height: 9),
            _test('24-hour horizon', controller.bt24.value),
            const SizedBox(height: 18),
            _disclaimer()
          ]))));
  Widget _price() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF292821), Color(0xFF51432B)]),
                borderRadius: BorderRadius.circular(22)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('TAMIL NADU ESTIMATED GOLD PRICE',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(
                  controller.tamilNaduPrice.value > 0
                      ? '₹${NumberFormat('#,##,##0.00').format(controller.tamilNaduPrice.value)}'
                      : '—',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800)),
              const Text(
                  '24K per gram • estimate using XAU + 15% duty assumption',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _purityPrice('22K', controller.tamilNadu22K.value)),
                Expanded(
                    child: _purityPrice('18K', controller.tamilNadu18K.value))
              ]),
              const SizedBox(height: 14),
              Row(children: [
                const Icon(Icons.schedule, color: Colors.white60, size: 14),
                const SizedBox(width: 6),
                Expanded(
                    child: Text('Updated: ${controller.updatedText}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12))),
                if (controller.loading.value)
                  const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
              ])
            ])),
        const SizedBox(height: 9),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('IBJA PRICE',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.black54)),
                        SizedBox(height: 4),
                        Text(
                            'Not available • official IBJA source not connected',
                            style:
                                TextStyle(fontSize: 12, color: Colors.black87))
                      ])),
                  Text(
                      controller.ibjaPrice.value > 0
                          ? '₹${NumberFormat('#,##,##0.00').format(controller.ibjaPrice.value)}'
                          : '—',
                      style: const TextStyle(fontWeight: FontWeight.w800))
                ]))),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('INTERNATIONAL XAU SPOT',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.black54)),
                        SizedBox(height: 4),
                        Text('INR per gram • before local price assumptions',
                            style:
                                TextStyle(fontSize: 11, color: Colors.black54))
                      ])),
                  Text(
                      controller.price.value > 0
                          ? '₹${NumberFormat('#,##,##0.00').format(controller.price.value)}'
                          : '—',
                      style: const TextStyle(fontWeight: FontWeight.w800))
                ])))
      ]);
  Widget _purityPrice(String title, double value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 3),
        Text(value > 0 ? '₹${NumberFormat('#,##,##0.00').format(value)}' : '—',
            style: const TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))
      ]);
  Widget _pastMovement() {
    return Row(children: [
      Expanded(
          child:
              _movementTile('PAST 12 HOURS', controller.past12hChange.value)),
      const SizedBox(width: 9),
      Expanded(
          child:
              _movementTile('PAST 24 HOURS', controller.past24hChange.value)),
    ]);
  }

  Widget _movementTile(String title, double? change) {
    final isDown = change != null && change < 0;
    final color = change == null
        ? Colors.black45
        : isDown
            ? const Color(0xFFB84A43)
            : const Color(0xFF24845A);
    final value = change == null
        ? '—'
        : '${change > 0 ? '+' : ''}${change.toStringAsFixed(2)}%';
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(13),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.black54)),
              const SizedBox(height: 7),
              Text(value,
                  style: TextStyle(
                      fontSize: 21, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 3),
              Text(
                  change == null
                      ? 'Waiting for enough history'
                      : isDown
                          ? 'Price decreased'
                          : 'Price increased',
                  style: const TextStyle(fontSize: 10, color: Colors.black54)),
            ])));
  }

  Widget _chart() {
    final data = controller.visiblePoints;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Row(
                  children: ['1H', '6H', '24H', '48H']
                      .map((r) => Expanded(
                          child: InkWell(
                              onTap: () => controller.range.value = r,
                              child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                      color: controller.range.value == r
                                          ? const Color(0xFFF4EBD8)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text(r,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: controller.range.value == r
                                              ? gold
                                              : Colors.black54))))))
                      .toList()),
              const SizedBox(height: 14),
              SizedBox(
                  height: 180,
                  child: data.length < 2
                      ? const Center(
                          child:
                              Text('Price history appears after data loads.'))
                      : LineChart(LineChartData(
                          gridData: const FlGridData(
                              show: true, drawVerticalLine: false),
                          titlesData: const FlTitlesData(
                              leftTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false))),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                              LineChartBarData(
                                  spots: data
                                      .asMap()
                                      .entries
                                      .map((e) => FlSpot(
                                          e.key.toDouble(), e.value.price))
                                      .toList(),
                                  isCurved: true,
                                  color: gold,
                                  barWidth: 2.5,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                      show: true,
                                      color: gold.withValues(alpha: .1)))
                            ]))),
              const SizedBox(height: 5),
              Text('${data.length} locally saved observations',
                  style: const TextStyle(fontSize: 11, color: Colors.black45))
            ])));
  }

  Widget _forecast(ForecastResult f) {
    final up = f.changePct >= 0,
        c = up ? const Color(0xFF24845A) : const Color(0xFFB84A43);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${f.hours} HOURS',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.black54)),
              const SizedBox(height: 7),
              FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('₹${NumberFormat('#,##,##0').format(f.price)}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800))),
              Text('${up ? '+' : ''}${f.changePct.toStringAsFixed(2)}%',
                  style: TextStyle(
                      color: c, fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 7),
              Text(f.direction,
                  style: TextStyle(
                      color: c, fontWeight: FontWeight.w700, fontSize: 12)),
              const Divider(height: 15),
              const Text('Estimated range',
                  style: TextStyle(fontSize: 10, color: Colors.black54)),
              Text(
                  '₹${NumberFormat('#,##,##0').format(f.low)} – ₹${NumberFormat('#,##,##0').format(f.high)}',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600)),
              const SizedBox(height: 5),
              Text(
                  'Signal strength ${f.score.toStringAsFixed(0)}/100 • not probability',
                  style: const TextStyle(fontSize: 10, color: Colors.black54))
            ])));
  }

  Widget _indicatorGrid(Indicators i) {
    final a = [
      ('EMA 12', _fmt(i.ema12)),
      ('EMA 26', _fmt(i.ema26)),
      ('RSI 14', _fmt(i.rsi14)),
      ('MACD', _fmt(i.macd)),
      ('ATR 14', _fmt(i.atr14)),
      (
        'Volatility',
        i.volatility == null ? '—' : '${i.volatility!.toStringAsFixed(2)}%'
      ),
      (
        'Momentum',
        i.momentum == null ? '—' : '${i.momentum!.toStringAsFixed(2)}%'
      )
    ];
    return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: a.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9),
        itemBuilder: (_, n) => Card(
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(a[n].$1,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black54)),
                      const SizedBox(height: 4),
                      Text(a[n].$2,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800))
                    ]))));
  }

  Widget _test(String title, BacktestMetrics? m) => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child: m == null
              ? Text('$title: collect more history to calculate metrics.',
                  style: const TextStyle(fontSize: 12, color: Colors.black54))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 9),
                  Row(children: [
                    _metric('Samples', '${m.samples}'),
                    _metric('MAE', '₹${m.mae.toStringAsFixed(2)}'),
                    _metric('RMSE', '₹${m.rmse.toStringAsFixed(2)}')
                  ]),
                  const SizedBox(height: 8),
                  Text(
                      'Directional accuracy: ${m.directionalAccuracy.toStringAsFixed(1)}% • Baseline MAE: ₹${m.baselineMae.toStringAsFixed(2)}',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.black54))
                ])));
  Widget _metric(String a, String b) => Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(a, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        Text(b,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))
      ]));
  Widget _heading(String a, String b) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(a,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 3),
        Text(b, style: const TextStyle(fontSize: 11, color: Colors.black54))
      ]);
  Widget _empty(String s) =>
      Card(child: Padding(padding: const EdgeInsets.all(17), child: Text(s)));
  Widget _error(String s) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF0ED),
          borderRadius: BorderRadius.circular(12)),
      child: Text('Live refresh unavailable: $s',
          style: const TextStyle(fontSize: 11, color: Color(0xFF8F3934))));
  Widget _disclaimer() => const Card(
      child: Padding(
          padding: EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.info_outline, color: gold),
              SizedBox(width: 8),
              Text('Important information',
                  style: TextStyle(fontWeight: FontWeight.w800))
            ]),
            SizedBox(height: 8),
            Text(
                'Future prices are experimental statistical estimates based on recent XAU price history. This is not a trained AI model, calibrated probability, financial advice or guarantee. Past 12H/24H movement is historical performance only and does not predict future direction. The INR conversion uses the latest available FX rate for historical points, so converted history is approximate. Tamil Nadu estimated price applies a configurable 15% duty assumption only; it is not an official retail quote or verified current duty rate. GST, local premiums and jeweller charges are excluded. IBJA is shown as unavailable until an official IBJA data source is connected. Verify prices before making decisions.',
                style:
                    TextStyle(fontSize: 11, height: 1.5, color: Colors.black54))
          ])));
  String _fmt(double? v) => v == null ? '—' : v.toStringAsFixed(2);
}
