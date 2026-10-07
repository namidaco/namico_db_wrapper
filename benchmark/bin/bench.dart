// by claude
// ignore_for_file: experimental_member_use

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import 'common.dart';

part 'kv_store.dart';

const _kOps = [
  'insertBulk', 'insertSingle', 'updateBulk', 'get', 'getNoDecode', 'contains', //
  'getAll', 'loadAllKeyed', 'loadKeys', 'delHalf', 'sizeMB', //
];
const _kDefaultPragmas = _Pragmas();
const _kTunedPragmas = _Pragmas(cacheSizeKiB: 16384, mmapSize: 256 << 20);

void main(List<String> args) {
  final phases = args.isEmpty ? {'json', 'schema', 'pragma', 'codec', 'extract', 'bind'} : args.toSet();
  final dir = Directory.systemTemp.createTempSync('kvbench').path;
  stdout.writeln('sqlite ${sqlite3.version.libVersion}, phases: $phases');

  final datasets = [
    _Dataset.generate('small/ytid (100k)', 100000, randomYtId, smallValue),
    _Dataset.generate('small/path (100k)', 100000, randomPath, smallValue),
    _Dataset.generate('medium/ytid (20k)', 20000, randomYtId, mediumValue),
    _Dataset.generate('large/ytid (4k)', 4000, randomYtId, largeValue),
  ];
  for (final ds in datasets) {
    stdout.writeln('${ds.name}: value ~${ds.jsonBytes}B json, key ~${ds.keys.first.length} chars e.g. ${ds.keys.first}');
  }
  stdout.writeln('times in ms, total for all keys of the dataset. insertSingle = 2000 autocommit puts');

  if (phases.contains('json')) _jsonCosts(datasets);

  if (phases.contains('schema')) {
    for (final ds in datasets) {
      _printTable('schema: ${ds.name}, text json, ${_kDefaultPragmas.toText()}', [
        for (final schema in _Schema.values) (schema.toText(), _runRepeated(dir, ds, schema, const _TextJsonCodec(), _kDefaultPragmas)),
      ]);
    }
  }

  if (phases.contains('pragma')) {
    const pragmaSets = [
      _Pragmas(),
      _Pragmas(cacheSizeKiB: 16384),
      _Pragmas(mmapSize: 256 << 20),
      _Pragmas(cacheSizeKiB: 16384, mmapSize: 256 << 20),
      _Pragmas(pageSize: 8192, cacheSizeKiB: 16384, mmapSize: 256 << 20),
      _Pragmas(cacheSizeKiB: 16384, mmapSize: 256 << 20, mutex: false),
    ];
    for (final ds in datasets) {
      for (final schema in _Schema.values) {
        if (schema == _Schema.withoutRowid && ds.jsonBytes > 1000) continue;
        _printTable('pragmas: ${ds.name}, ${schema.toText()}, text json', [
          for (final pragmas in pragmaSets) (pragmas.toText(), _runRepeated(dir, ds, schema, const _TextJsonCodec(), pragmas)),
        ]);
      }
    }
  }

  if (phases.contains('codec')) {
    const codecs = [_TextJsonCodec(), _TextReadBytesCodec(), _TextBytesCodec(), _BlobJsonCodec(), _BlobJsonbCodec()];
    for (final ds in datasets) {
      _printTable('codec: ${ds.name}, ${_Schema.current.toText()}, ${_kTunedPragmas.toText()}', [
        for (final codec in codecs) (codec.name, _runRepeated(dir, ds, _Schema.current, codec, _kTunedPragmas)),
      ]);
    }
  }

  if (phases.contains('extract')) _extractBench(dir, [datasets[2], datasets[3]]);

  if (phases.contains('bind')) _bindBench(dir, [datasets[0], datasets[3]]);

  Directory(dir).deleteSync(recursive: true);
}

Map<String, double> _runOnce(String dir, _Dataset ds, _Schema schema, _ValueCodec codec, _Pragmas pragmas) {
  final res = <String, double>{};
  final store = _KVStore.create('$dir/bench.db', schema, codec, pragmas);
  final keys = ds.keys;
  final values = ds.values;
  final count = keys.length;

  void putAll() {
    for (int i = 0; i < count; i++) {
      store.put(keys[i], values[i]);
    }
  }

  res['insertBulk'] = timeMs(() => store.transaction(putAll));

  final extraKeys = ds.extraKeys.length > 2000 ? ds.extraKeys.sublist(0, 2000) : ds.extraKeys;
  res['insertSingle'] = timeMs(() {
    for (int i = 0; i < extraKeys.length; i++) {
      store.put(extraKeys[i], values[i]);
    }
  });

  res['updateBulk'] = timeMs(() => store.transaction(putAll));

  final shuffled = [...keys]..shuffle(Random(3));
  res['get'] = bestOf(2, () {
    for (int i = 0; i < count; i++) {
      if (store.get(shuffled[i]) == null) throw StateError('missing');
    }
  });
  res['getNoDecode'] = bestOf(2, () {
    for (int i = 0; i < count; i++) {
      if (store.getNoDecode(shuffled[i]) == null) throw StateError('missing');
    }
  });
  res['contains'] = bestOf(2, () {
    for (int i = 0; i < count; i++) {
      if (!store.containsKey(shuffled[i])) throw StateError('missing');
    }
  });
  res['getAll'] = bestOf(2, () {
    if (store.getAll(shuffled) != count) throw StateError('missing');
  });
  res['loadAllKeyed'] = bestOf(2, store.loadEverythingKeyed);
  res['loadKeys'] = bestOf(2, store.loadAllKeys);
  res['sizeMB'] = store.checkpointAndGetSize() / (1 << 20);

  final halfKeys = shuffled.sublist(0, count ~/ 2);
  res['delHalf'] = timeMs(() => store.deleteBulk(halfKeys));
  store.close();
  return res;
}

Map<String, double> _runRepeated(String dir, _Dataset ds, _Schema schema, _ValueCodec codec, _Pragmas pragmas, {int repeat = 2}) {
  final best = <String, double>{};
  for (int i = 0; i < repeat; i++) {
    final res = _runOnce(dir, ds, schema, codec, pragmas);
    for (final e in res.entries) {
      final prev = best[e.key];
      best[e.key] = prev == null ? e.value : min(prev, e.value);
    }
  }
  return best;
}

void _printTable(String title, List<(String, Map<String, double>)> rows) {
  stdout.writeln('\n### $title');
  final alignCells = _kOps.map((_) => '---:');
  stdout.writeln('| config | ${_kOps.join(' | ')} |');
  stdout.writeln('|---|${alignCells.join('|')}|');
  for (final (label, res) in rows) {
    final cells = _kOps.map((op) => res[op]?.toStringAsFixed(op == 'sizeMB' ? 1 : 0) ?? '-');
    stdout.writeln('| $label | ${cells.join(' | ')} |');
  }
}

void _jsonCosts(List<_Dataset> datasets) {
  stdout.writeln('\n### pure dart json cost (µs per value, best of 3, 2000 values)');
  stdout.writeln(
    '| dataset | bytes | jsonEncode | jsonEncode+utf8.encode | JsonUtf8Encoder | jsonb.encode | jsonDecode(String) | fused utf8 decode | jsonb.decode | utf8.decode only |',
  );
  stdout.writeln('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|');
  for (final ds in datasets) {
    final values = ds.values.take(2000).toList();
    final texts = values.map(jsonEncode).toList();
    final bytesList = values.map(utf8JsonEncode).toList();
    final jsonbList = values.map(jsonb.encode).toList();

    double usPerValue<T>(List<T> items, void Function(T item) fn) {
      final ms = bestOf(3, () {
        for (final item in items) {
          fn(item);
        }
      });
      return ms * 1000 / items.length;
    }

    final cols = [
      usPerValue(values, jsonEncode),
      usPerValue(values, (v) => utf8.encode(jsonEncode(v))),
      usPerValue(values, utf8JsonEncode),
      usPerValue(values, jsonb.encode),
      usPerValue(texts, jsonDecode),
      usPerValue(bytesList, utf8JsonDecode),
      usPerValue(jsonbList, jsonb.decode),
      usPerValue(bytesList, utf8.decode),
    ];
    final colsText = cols.map((c) => c.toStringAsFixed(2));
    stdout.writeln('| ${ds.name} | ${ds.jsonBytes} | ${colsText.join(' | ')} |');
  }
}

void _extractBench(String dir, List<_Dataset> datasets) {
  stdout.writeln('\n### json_extract (2 paths) full scan, ms, ${_kTunedPragmas.toText()}');
  stdout.writeln('| dataset | text json | text via bytes | blob utf8 json | jsonb |');
  stdout.writeln('|---|---:|---:|---:|---:|');
  const codecs = [_TextJsonCodec(), _TextBytesCodec(), _BlobJsonCodec(), _BlobJsonbCodec()];
  for (final ds in datasets) {
    final isLarge = ds.jsonBytes > 10000;
    final paths = isLarge ? [r'$.info.title', r'$.info.channelName'] : [r'$.title', r'$.channel.name'];
    final sql = "SELECT key, json_extract(value, '${paths[0]}'), json_extract(value, '${paths[1]}') FROM kv";
    final cells = <String>[];
    for (final codec in codecs) {
      final store = _KVStore.create('$dir/extract.db', _Schema.current, codec, _kTunedPragmas);
      store.transaction(() {
        for (int i = 0; i < ds.keys.length; i++) {
          store.put(ds.keys[i], ds.values[i]);
        }
      });
      int nonNullCount = 0;
      try {
        final ms = bestOf(3, () {
          nonNullCount = 0;
          final st = store.db.prepare(sql);
          final raw = st.raw;
          while (raw.step()) {
            if (raw.columnType(1) != SqlType.SQLITE_NULL) nonNullCount++;
          }
          st.close();
        });
        final missingNote = nonNullCount == ds.keys.length ? '' : ' (nonNull $nonNullCount)';
        cells.add('${ms.toStringAsFixed(0)}$missingNote');
      } catch (e) {
        final firstLine = e.toString().split('\n').first;
        cells.add('ERR $firstLine');
      }
      store.close();
    }
    stdout.writeln('| ${ds.name} | ${cells.join(' | ')} |');
  }
}

void _bindBench(String dir, List<_Dataset> datasets) {
  stdout.writeln('\n### binding: upsert all keys in one transaction, values pre-encoded, ms, ${_kTunedPragmas.toText()}');
  stdout.writeln('| dataset | execute([key, text]) | raw bindText x2 | raw bindText + bindBlob CAST |');
  stdout.writeln('|---|---:|---:|---:|');
  const upsertTextSql = 'INSERT INTO kv (key, value) VALUES (?, ?) ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value';
  const upsertCastSql = 'INSERT INTO kv (key, value) VALUES (?, CAST(? AS TEXT)) ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value';
  for (final ds in datasets) {
    final keys = ds.keys;
    final texts = ds.values.map(jsonEncode).toList();
    final bytesList = ds.values.map(utf8JsonEncode).toList();
    final count = keys.length;

    double run(String sql, void Function(PreparedStatement st, int i) putOne) {
      double best = double.infinity;
      for (int rep = 0; rep < 3; rep++) {
        final store = _KVStore.create('$dir/bind.db', _Schema.current, const _TextJsonCodec(), _kTunedPragmas);
        final st = store.db.prepare(sql, persistent: true);
        final ms = timeMs(() => store.transaction(() {
              for (int i = 0; i < count; i++) {
                putOne(st, i);
              }
            }));
        best = min(best, ms);
        st.close();
        store.close();
      }
      return best;
    }

    final executeMs = run(upsertTextSql, (st, i) => st.execute([keys[i], texts[i]]));
    final rawTextMs = run(upsertTextSql, (st, i) {
      final raw = st.raw;
      st.reset();
      raw.bindText(1, keys[i]);
      raw.bindText(2, texts[i]);
      raw.step();
    });
    final rawBlobMs = run(upsertCastSql, (st, i) {
      final raw = st.raw;
      st.reset();
      raw.bindText(1, keys[i]);
      raw.bindBlob(2, bytesList[i]);
      raw.step();
    });
    stdout.writeln('| ${ds.name} | ${executeMs.toStringAsFixed(0)} | ${rawTextMs.toStringAsFixed(0)} | ${rawBlobMs.toStringAsFixed(0)} |');
  }
}

class _Dataset {
  final String name;
  final List<String> keys;
  final List<String> extraKeys;
  final List<Map<String, dynamic>> values;
  final int jsonBytes;

  _Dataset(this.name, this.keys, this.extraKeys, this.values) : jsonBytes = utf8JsonEncode(values.first).length;

  factory _Dataset.generate(String name, int count, String Function(Random r) keyGen, Map<String, dynamic> Function(Random r) valueGen) {
    final allKeys = generateKeys(count + count ~/ 10, keyGen, name.hashCode);
    final r = Random(7);
    final values = List.generate(count, (_) => valueGen(r));
    final keys = allKeys.sublist(0, count);
    final extraKeys = allKeys.sublist(count);
    return _Dataset(name, keys, extraKeys, values);
  }
}
