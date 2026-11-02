// by claude
import 'dart:async';
import 'dart:isolate';

import 'package:test/test.dart';

import 'package:namico_db_wrapper/namico_db_wrapper.dart';

void main() {
  group('spawner exits without disposing', () {
    test('PortsProvider worker gets disposed', () async {
      final reports = ReceivePort();
      final reportPort = reports.sendPort;
      await Isolate.run(() async {
        final provider = _ReportingProvider(reportPort);
        await provider.initialize();
      });
      final report = await reports.first.timeout(const Duration(seconds: 5));
      expect(report, PortsProviderMessages.disposed);
    });

    test('PortsComm worker gets disposed', () async {
      final reports = ReceivePort();
      final reportPort = reports.sendPort;
      await Isolate.run(() async {
        final comm = PortsComm();
        comm.listen((_) {});
        await Isolate.spawn(_reportingWorker, (comm.items.sendPort, reportPort));
        await comm.sendPort;
      });
      final report = await reports.first.timeout(const Duration(seconds: 5));
      expect(report, PortsProviderMessages.disposed);
    });

    test('closed PortsComm worker is disposed once', () async {
      final reports = ReceivePort();
      final reportPort = reports.sendPort;
      await Isolate.run(() async {
        final comm = PortsComm();
        comm.listen((_) {});
        await Isolate.spawn(_reportingWorker, (comm.items.sendPort, reportPort));
        await comm.sendPort;
        comm.close();
      });
      final received = <Object?>[];
      final sub = reports.listen(received.add);
      await Future.delayed(const Duration(seconds: 1));
      await sub.cancel();
      expect(received, [PortsProviderMessages.disposed]);
    });
  });
}

class _ReportingProvider with PortsProvider<(SendPort, SendPort)> {
  final SendPort _reportPort;
  _ReportingProvider(this._reportPort);

  @override
  IsolateFunctionReturnBuild<(SendPort, SendPort)> isolateFunction(SendPort port) {
    return IsolateFunctionReturnBuild(_reportingWorker, (port, _reportPort));
  }

  @override
  void onResult(dynamic result) {}
}

void _reportingWorker((SendPort, SendPort) ports) {
  final (sendPort, reportPort) = ports;
  final recievePort = ReceivePort();
  recievePort.listen((p) {
    reportPort.send(p);
    if (p == PortsProviderMessages.disposed) recievePort.close();
  });
  sendPort.send(recievePort.sendPort);
  sendPort.send(PortsProviderMessages.prepared);
}
