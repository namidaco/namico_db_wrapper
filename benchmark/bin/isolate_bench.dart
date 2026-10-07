// by claude

import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'common.dart';

Future<void> main() async {
  final r = Random(1);
  final payloadSets = {
    'small (129B)': List.generate(64, (_) => utf8JsonEncode(smallValue(r))),
    'medium (1.3KB)': List.generate(64, (_) => utf8JsonEncode(mediumValue(r))),
    'large (16.5KB)': List.generate(64, (_) => utf8JsonEncode(largeValue(r))),
  };

  // -- what `_DBWrapperSyncAutoDisposable` does on every call
  Timer? timer;
  final timerMs = bestOf(3, () {
    for (int i = 0; i < 100000; i++) {
      timer?.cancel();
      timer = Timer(const Duration(minutes: 5), () {});
    }
  });
  timer?.cancel();
  print('Timer cancel+create: ${(timerMs * 1000 / 100000).toStringAsFixed(3)} µs/op');

  final sw = Stopwatch()..start();
  int lastUsedUs = 0;
  final stopwatchMs = bestOf(3, () {
    for (int i = 0; i < 100000; i++) {
      lastUsedUs = sw.elapsedMicroseconds;
    }
  });
  print('Stopwatch timestamp (alternative): ${(stopwatchMs * 1000 / 100000).toStringAsFixed(3)} µs/op ($lastUsedUs)');

  print('\n| payload | sync decode only | async: decoded map back (current) | async: bytes back + decode on main | async: transferable + decode on main | awaited one by one vs Future.wait |');
  print('|---|---:|---:|---:|---:|---:|');
  for (final MapEntry(key: name, value: payloads) in payloadSets.entries) {
    final worker = await _Worker.spawn(payloads);
    const count = 2000;
    await Future.wait([for (int i = 0; i < 200; i++) worker.request(_ReplyMode.decodedMap, i)]);

    final syncMs = bestOf(3, () {
      for (int i = 0; i < count; i++) {
        utf8JsonDecode(payloads[i % payloads.length]);
      }
    });

    Future<double> runMode(_ReplyMode mode) async {
      double best = double.infinity;
      for (int rep = 0; rep < 3; rep++) {
        final ms = await timeMsAsync(() async {
          for (int i = 0; i < count; i++) {
            final res = await worker.request(mode, i);
            switch (mode) {
              case _ReplyMode.decodedMap:
                break;
              case _ReplyMode.bytes:
                utf8JsonDecode(res as Uint8List);
              case _ReplyMode.transferable:
                final bytes = (res as TransferableTypedData).materialize().asUint8List();
                utf8JsonDecode(bytes);
            }
          }
        });
        best = min(best, ms);
      }
      return best;
    }

    final decodedMapMs = await runMode(_ReplyMode.decodedMap);
    final bytesMs = await runMode(_ReplyMode.bytes);
    final transferableMs = await runMode(_ReplyMode.transferable);
    final parallelMs = await timeMsAsync(() => Future.wait([for (int i = 0; i < count; i++) worker.request(_ReplyMode.decodedMap, i)]));
    String perOp(double ms) => '${(ms * 1000 / count).toStringAsFixed(1)} µs';
    print('| $name | ${perOp(syncMs)} | ${perOp(decodedMapMs)} | ${perOp(bytesMs)} | ${perOp(transferableMs)} | ${perOp(decodedMapMs)} vs ${perOp(parallelMs)} |');
  }
  Isolate.current.kill();
}

/// Mimics `DBWrapperAsync` messaging.
class _Worker {
  final SendPort _sendPort;
  final Map<int, Completer<Object?>> _completers;
  int _token = 0;

  _Worker._(this._sendPort, this._completers);

  static Future<_Worker> spawn(List<Uint8List> payloads) async {
    final receivePort = ReceivePort();
    final completers = <int, Completer<Object?>>{};
    final readyCompleter = Completer<SendPort>();
    receivePort.listen((message) {
      if (message is SendPort) return readyCompleter.complete(message);
      final reply = message as List;
      final completer = completers.remove(reply[0]);
      completer?.complete(reply[1]);
    });
    await Isolate.spawn(_entry, [receivePort.sendPort, payloads]);
    final sendPort = await readyCompleter.future;
    return _Worker._(sendPort, completers);
  }

  Future<Object?> request(_ReplyMode mode, int index) {
    final token = _token++;
    final completer = _completers[token] = Completer<Object?>();
    _sendPort.send([token, mode.index, index]);
    return completer.future;
  }

  static void _entry(List args) {
    final replyPort = args[0] as SendPort;
    final payloads = args[1] as List<Uint8List>;
    final receivePort = ReceivePort();
    replyPort.send(receivePort.sendPort);
    receivePort.listen((message) {
      final request = message as List;
      final mode = _ReplyMode.values[request[1] as int];
      final index = request[2] as int;
      final bytes = payloads[index % payloads.length];
      final Object? res = switch (mode) {
        _ReplyMode.decodedMap => utf8JsonDecode(bytes),
        _ReplyMode.bytes => Uint8List.fromList(bytes),
        _ReplyMode.transferable => TransferableTypedData.fromList([bytes]),
      };
      replyPort.send([request[0], res]);
    });
  }
}

enum _ReplyMode {
  decodedMap,
  bytes,
  transferable,
  ;
}
