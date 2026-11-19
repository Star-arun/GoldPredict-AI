// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import '../models/market_models.dart';

// class MarketDataProvider {
//   static const spotUrl =
//       'https://xaus.com/api/v1/spot?currency=INR&unit=gram&compact=1';
//   static const historyUrl =
//       'https://xaus.com/api/v1/intraday?symbol=xau&hours=48';
//   final http.Client client;
//   MarketDataProvider({http.Client? client}) : client = client ?? http.Client();
//   Future<double> fetchSpot() async {
//     final r = await client
//         .get(Uri.parse(spotUrl))
//         .timeout(const Duration(seconds: 20));
//     if (r.statusCode != 200) throw Exception('Spot HTTP ${r.statusCode}');
//     // final n = _number(jsonDecode(r.body),
//     //     ['price', 'spot', 'value', 'rate', 'inr_per_gram', 'price_per_gram']);
//     final n = _number(jsonDecode(r.body)['xau'], ['price']);
//     if (n == null || n <= 0)
//       throw const FormatException('Unrecognized spot JSON fields');
//     return n;
//   }

//   Future<List<PricePoint>> fetchHistory() async {
//     final r = await client
//         .get(Uri.parse(historyUrl))
//         .timeout(const Duration(seconds: 20));
//     if (r.statusCode != 200) throw Exception('History HTTP ${r.statusCode}');
//     final data = jsonDecode(r.body);
//     final rows = data is List ? data : _rows(data);
//     final out = <PricePoint>[];
//     for (final x in rows) {
//       if (x is! Map) continue;
//       final m = Map<String, dynamic>.from(x);
//       final t =
//           m['timestamp'] ?? m['time'] ?? m['datetime'] ?? m['date'] ?? m['t'];
//       // final price = _number(
//       //     m, ['price', 'value', 'close', 'rate', 'inr', 'price_per_gram']);
//       final price = _number(m, ['p']);
//       DateTime? dt;
//       if (t is String) dt = DateTime.tryParse(t)?.toLocal();
//       if (t is num) {
//         final ms = t < 100000000000 ? (t * 1000).round() : t.round();
//         dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
//       }
//       if (dt != null && price != null && price > 0)
//         out.add(PricePoint(time: dt, price: price));
//     }
//     out.sort((a, b) => a.time.compareTo(b.time));
//     return out;
//   }

//   List<dynamic> _rows(dynamic d) {
//     if (d is Map) {
//       for (final k in [
//         'data',
//         'prices',
//         'points',
//         'history',
//         'result',
//         'items'
//       ]) {
//         final v = d[k];
//         if (v is List) return v;
//         if (v is Map) {
//           for (final n in ['data', 'prices', 'points', 'items']) {
//             if (v[n] is List) return v[n] as List;
//           }
//         }
//       }
//     }
//     return [];
//   }

//   double? _number(dynamic d, List<String> keys) {
//     print(d.runtimeType);
//     if (d is! Map) return null;
//     for (final k in keys) {
//       final v = d[k];
//       if (v is num) return v.toDouble();
//       if (v is String) {
//         final x = double.tryParse(v.replaceAll(',', ''));
//         if (x != null) return x;
//       }
//     }
//     return null;
//   }

//   void dispose() => client.close();
// }

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/market_models.dart';

class MarketDataProvider {
  static const spotUrl =
      'https://xaus.com/api/v1/spot?currency=INR&unit=gram&compact=1';

  static const historyUrl =
      'https://xaus.com/api/v1/intraday?symbol=xau&hours=48';

  // Troy ounce to gram conversion
  static const double troyOunceToGram = 31.1034768;

  final http.Client client;

  double? _fxRate;

  double? get fxRate => _fxRate;

  MarketDataProvider({http.Client? client}) : client = client ?? http.Client();

  // Fetch current spot price and USD to INR exchange rate
  Future<double> fetchSpot() async {
    final r = await client
        .get(Uri.parse(spotUrl))
        .timeout(const Duration(seconds: 20));

    if (r.statusCode != 200) {
      throw Exception('Spot HTTP ${r.statusCode}');
    }

    final data = jsonDecode(r.body);

    if (data is! Map) {
      throw const FormatException('Invalid spot JSON');
    }

    final n = _number(data['xau'], ['price']);
    final fx = _number(data, ['fx_rate']);

    if (n == null || n <= 0) {
      throw const FormatException('Spot price not found');
    }

    if (fx == null || fx <= 0) {
      throw const FormatException('USD/INR exchange rate not found');
    }

    _fxRate = fx;

    return n;
  }

  // Fetch historical prices and convert USD/troy ounce to INR/gram
  Future<List<PricePoint>> fetchHistory({
    required double fxRate,
  }) async {
    final r = await client
        .get(Uri.parse(historyUrl))
        .timeout(const Duration(seconds: 20));

    if (r.statusCode != 200) {
      throw Exception('History HTTP ${r.statusCode}');
    }

    final data = jsonDecode(r.body);
    final rows = data is List ? data : _rows(data);

    final out = <PricePoint>[];

    for (final x in rows) {
      if (x is! Map) continue;

      final m = Map<String, dynamic>.from(x);

      final t =
          m['timestamp'] ?? m['time'] ?? m['datetime'] ?? m['date'] ?? m['t'];

      // API history price: USD / troy ounce
      final rawPrice = _number(m, ['p']);

      DateTime? dt;

      if (t is String) {
        dt = DateTime.tryParse(t)?.toLocal();
      }

      if (t is num) {
        final ms = t < 100000000000 ? (t * 1000).round() : t.round();

        dt = DateTime.fromMillisecondsSinceEpoch(
          ms,
          isUtc: true,
        ).toLocal();
      }

      if (dt != null && rawPrice != null && rawPrice > 0) {
        // Convert USD/troy ounce to INR/gram
        final inrPerGram = (rawPrice * fxRate) / troyOunceToGram;

        out.add(
          PricePoint(
            time: dt,
            price: inrPerGram,
          ),
        );
      }
    }

    out.sort((a, b) => a.time.compareTo(b.time));

    return out;
  }

  List<dynamic> _rows(dynamic d) {
    if (d is Map) {
      for (final k in [
        'data',
        'prices',
        'points',
        'history',
        'result',
        'items',
      ]) {
        final v = d[k];

        if (v is List) return v;

        if (v is Map) {
          for (final n in [
            'data',
            'prices',
            'points',
            'items',
          ]) {
            if (v[n] is List) {
              return v[n] as List;
            }
          }
        }
      }
    }

    return [];
  }

  double? _number(dynamic d, List<String> keys) {
    if (d is! Map) return null;

    for (final k in keys) {
      final v = d[k];

      if (v is num) return v.toDouble();

      if (v is String) {
        final x = double.tryParse(
          v.replaceAll(',', ''),
        );

        if (x != null) return x;
      }
    }

    return null;
  }

  void dispose() => client.close();
}
