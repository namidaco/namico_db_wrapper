import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

enum PortsProviderMessages {
  prepared,
  disposed,
}

class IsolateFunctionReturnBuild<T> {
  final void Function(T message) entryPoint;
  final T message;

  const IsolateFunctionReturnBuild(
    this.entryPoint,
    this.message,
  );
}

mixin PortsProvider<E> {
  bool get isInitialized => _isInitialized ?? false;

  Completer<SendPort>? _portCompleter;
  ReceivePort? _recievePort;
  StreamSubscription? _streamSub;
  Isolate? _isolate;

  bool? _isInitialized;
  Completer<void>? _initializingCompleter;

  Future<void> sendPort(Object? message) async {
    (await _portCompleter?.future)?.send(message);
  }

  static bool isDisposeMessage(dynamic message) => message == PortsProviderMessages.disposed;

  @protected
  Future<void> disposePort() async {
    _recievePort?.close();
    _streamSub?.cancel();
    await sendPort(PortsProviderMessages.disposed);
    _isolate?.kill();
    _isInitialized = false;
    onPreparing(false);
    _initializingCompleter = null;
    _portCompleter = null;
    _recievePort = null;
    _streamSub = null;
    _isolate = null;
  }

  Future<SendPort> preparePortRaw({
    required void Function(dynamic result) onResult,
    required Future<void> Function(SendPort itemsSendPort) isolateFunction,
  }) async {
    final portN = _portCompleter;
    if (portN != null) return await portN.future;

    await disposePort();
    _portCompleter = Completer<SendPort>();
    _recievePort = ReceivePort();
    _initializingCompleter = Completer<void>();
    _streamSub = _recievePort?.listen((result) {
      if (result is SendPort) {
        final pc = _portCompleter;
        if (pc != null && pc.isCompleted == false) pc.complete(result);
      } else {
        onResult(result);
      }
    });
    await isolateFunction(_recievePort!.sendPort);
    return await _portCompleter!.future;
  }

  @protected
  void onResult(dynamic result);

  @protected
  IsolateFunctionReturnBuild<E> isolateFunction(SendPort port);

  void onPreparing(bool prepared) {}

  Future<void> initialize() async {
    if (_isInitialized == true || _initializingCompleter?.isCompleted == true) return;
    if (_initializingCompleter != null) return _initializingCompleter?.future;

    _isInitialized = false;
    onPreparing(false);

    await preparePortRaw(
      onResult: (result) async {
        if (result == PortsProviderMessages.prepared) {
          final ic = _initializingCompleter;
          if (ic != null && ic.isCompleted == false) ic.complete();
        } else {
          onResult(result);
        }
      },
      isolateFunction: (itemsSendPort) async {
        final isolateFn = isolateFunction(itemsSendPort);
        _isolate = await Isolate.spawn(isolateFn.entryPoint, isolateFn.message);
      },
    );
    await _initializingCompleter?.future;
    _isInitialized = true;
    onPreparing(true);
  }
}
