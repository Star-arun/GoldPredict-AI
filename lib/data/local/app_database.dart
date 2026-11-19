import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/market_models.dart';

class AppDatabase {
  AppDatabase._();
  static final instance = AppDatabase._();
  Database? _db;
  Future<Database> get db async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'goldpredict_ai.db');
    _db = await openDatabase(path, version: 2, onCreate: (d, v) async {
      await d.execute(
          'CREATE TABLE prices(time INTEGER PRIMARY KEY,price REAL NOT NULL)');
      await d.execute(
          'CREATE TABLE candles(time INTEGER PRIMARY KEY,open REAL,high REAL,low REAL,close REAL)');
    }, onUpgrade: (d, oldVersion, newVersion) async {
      // Stored price units changed when history was corrected to INR per gram.
      // Clear old rows once so old USD/oz points cannot be mixed into new candles.
      await d.delete('prices');
      await d.delete('candles');
    });
    return _db!;
  }

  Future<void> savePoints(List<PricePoint> xs) async {
    final d = await db, b = d.batch();
    for (final x in xs) {
      b.insert(
          'prices', {'time': x.time.millisecondsSinceEpoch, 'price': x.price},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await b.commit(noResult: true);
  }

  Future<List<PricePoint>> getPoints() async {
    final rows = await (await db).query('prices', orderBy: 'time ASC');
    return rows
        .map((r) => PricePoint(
            time: DateTime.fromMillisecondsSinceEpoch(r['time'] as int),
            price: (r['price'] as num).toDouble()))
        .toList();
  }

  Future<void> saveCandles(List<Candle> xs) async {
    final d = await db, b = d.batch();
    for (final x in xs) {
      b.insert('candles', x.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await b.commit(noResult: true);
  }

  Future<List<Candle>> getCandles() async {
    final rows = await (await db).query('candles', orderBy: 'time ASC');
    return rows.map(Candle.fromMap).toList();
  }

  Future<void> deleteOlderThan48Hours() async {
    final database = await db;

    final cutoffTime = DateTime.now()
        .subtract(const Duration(hours: 48))
        .millisecondsSinceEpoch;

    await database.transaction((txn) async {
      await txn.delete(
        'prices',
        where: 'time < ?',
        whereArgs: [cutoffTime],
      );

      await txn.delete(
        'candles',
        where: 'time < ?',
        whereArgs: [cutoffTime],
      );
    });
  }
}
