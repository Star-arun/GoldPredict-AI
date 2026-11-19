import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/market_models.dart';

class MarketDataProvider {
  static const spotUrl =
      'https://xaus.com/api/v1/spot?currency=INR&unit=gram&compact=1';
  static const historyUrl =
      'https://xaus.com/api/v1/intraday?symbol=xau&hours=48';
  static const double gramsPerTroyOunce = 31.1034768;

  final http.Client client;
  double? _fxRate;

  double? get fxRate => _fxRate;

  MarketDataProvider({http.Client? client}) : client = client ?? http.Client();

  /// API's xau.price is already INR per gram.
  Future<double> fetchSpot() async {
    final response = await client
        .get(Uri.parse(spotUrl))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Spot HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Invalid spot response');
    }
    final xau = decoded['xau'];
    final price = _number(xau, ['price']);
    _fxRate = _number(decoded, ['fx_rate']);

    if (price == null || price <= 0 || _fxRate == null || _fxRate! <= 0) {
      throw const FormatException('Missing XAU price or USD/INR rate');
    }
    return price;
  }

  /// History `p` is USD per troy ounce, not INR per gram.
  /// Uses the latest FX rate returned by the spot endpoint to convert it.
  /// Historical FX is not provided by this endpoint, so old points are
  /// approximate INR/gram conversions using the current FX rate.
  Future<List<PricePoint>> fetchHistory({required double fxRate}) async {
    final response = await client
        .get(Uri.parse(historyUrl))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('History HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final rows = decoded is Map ? decoded['points'] : null;
    if (rows is! List) {
      throw const FormatException('History response has no points array');
    }

    final points = <PricePoint>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final timestamp = row['t'];
      final usdPerOunce = _number(row, ['p']);
      if (timestamp is! num || usdPerOunce == null || usdPerOunce <= 0) {
        continue;
      }

      final milliseconds = timestamp < 100000000000
          ? (timestamp * 1000).round()
          : timestamp.round();
      final time = DateTime.fromMillisecondsSinceEpoch(
        milliseconds,
        isUtc: true,
      ).toLocal();
      final inrPerGram = usdPerOunce * fxRate / gramsPerTroyOunce;
      if (inrPerGram > 0 && inrPerGram.isFinite) {
        points.add(PricePoint(time: time, price: inrPerGram));
      }
    }

    points.sort((a, b) => a.time.compareTo(b.time));
    return points;
  }

  double? _number(dynamic object, List<String> keys) {
    if (object is! Map) return null;
    for (final key in keys) {
      final value = object[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.replaceAll(',', ''));
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  void dispose() => client.close();
}
