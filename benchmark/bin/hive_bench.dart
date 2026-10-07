// by claude

import 'dart:io';
import 'dart:math';

import 'package:hive_ce/hive.dart';

import 'common.dart';

Future<void> main() async {
  final dir = Directory.systemTemp.createTempSync('kvhive').path;
  Hive.init(dir);
  final datasets = [
    ('small/ytid (100k)', 100000, randomYtId, smallValue),
    ('small/path (100k)', 100000, randomPath, smallValue),
    ('large/ytid (4k)', 4000, randomYtId, largeValue),
  ];
  stdout.writeln('| hive_ce | putAll | 2000 single puts | get (Box, in-memory) | get (LazyBox, awaited) | reopen Box (= load all) | sizeMB |');
  stdout.writeln('|---|---:|---:|---:|---:|---:|---:|');
  for (int dsIndex = 0; dsIndex < datasets.length; dsIndex++) {
    final (name, count, keyGen, valueGen) = datasets[dsIndex];
    final allKeys = generateKeys(count + 2000, keyGen, name.hashCode);
    final keys = allKeys.sublist(0, count);
    final extraKeys = allKeys.sublist(count);
    final r = Random(7);
    final values = List.generate(count, (_) => valueGen(r));
    final boxName = 'b$dsIndex';

    var box = await Hive.openBox<Map>(boxName);
    final entries = {for (int i = 0; i < count; i++) keys[i]: values[i]};
    final putAllMs = await timeMsAsync(() => box.putAll(entries));
    final singlePutsMs = await timeMsAsync(() async {
      for (int i = 0; i < extraKeys.length; i++) {
        await box.put(extraKeys[i], values[i]);
      }
    });

    final shuffled = [...keys]..shuffle(Random(3));
    final getMs = bestOf(2, () {
      for (final key in shuffled) {
        if (box.get(key) == null) throw StateError('missing');
      }
    });
    await box.close();
    final reopenMs = await timeMsAsync(() async => box = await Hive.openBox<Map>(boxName));
    await box.close();

    final lazyBox = await Hive.openLazyBox<Map>(boxName);
    final lazyGetMs = await timeMsAsync(() async {
      for (final key in shuffled) {
        final value = await lazyBox.get(key);
        if (value == null) throw StateError('missing');
      }
    });
    await lazyBox.close();

    final sizeInMB = File('$dir/$boxName.hive').lengthSync() / (1 << 20);
    final cells = [putAllMs, singlePutsMs, getMs, lazyGetMs, reopenMs].map((ms) => ms.toStringAsFixed(0));
    stdout.writeln('| $name | ${cells.join(' | ')} | ${sizeInMB.toStringAsFixed(1)} |');
  }
  await Hive.close();
  Directory(dir).deleteSync(recursive: true);
}
