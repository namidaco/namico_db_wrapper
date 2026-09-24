import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

/// Isolates spawned by a [PortsProvider] must first send their own [SendPort], then [PortsProviderMessages.prepared] once ready.
mixin PortsProvider<E> {
  static final _activePortsProviders = <PortsProvider, bool>{};
  static Future<void> disposeAll() async {
    final providers = _activePortsProviders.keys.toList(growable: false);
    _activePortsProviders.clear();
    await Future.wait(providers.map((e) => e.onDisposeAll()));
  }

  bool get isInitialized => _isInitialized ?? false;

  /// When true, [disposePort] only asks the isolate to release its resources and exit on its own,
  /// otherwise it's killed right away. Enable only for isolates that close all their ports on [PortsProviderMessages.disposed].
  @protected
  bool get disposeGracefully => false;

  /// Completes with null if disposed before the isolate reported back.
  Completer<SendPort?>? _portCompleter;
  SendPort? _portCompleterResult;
  ReceivePort? _recievePort;
  StreamSubscription? _streamSub;
  Isolate? _isolate;

  bool? _isInitialized;
  Completer<void>? _initializingCompleter;

  Future<void> sendPort(Object? message) async {
    (_portCompleterResult ?? await _portCompleter?.future)?.send(message);
  }

  @protected
  Future<void> onDisposeAll() => disposePort();

  @protected
  Future<void> disposePort({bool resetCompleter = true}) async {
    _activePortsProviders.remove(this);
    _recievePort?.close();
    _streamSub?.cancel();
    final sendPort = _portCompleterResult;
    sendPort?.send(PortsProviderMessages.disposed);
    if (sendPort == null || !disposeGracefully) _isolate?.kill(priority: Isolate.immediate);
    final portCompleter = _portCompleter;
    if (portCompleter != null && !portCompleter.isCompleted) portCompleter.complete(null);
    _isInitialized = false;
    onPreparing(false);
    if (resetCompleter) {
      final initializingCompleter = _initializingCompleter;
      if (initializingCompleter != null && !initializingCompleter.isCompleted) initializingCompleter.complete();
      _initializingCompleter = null;
    }
    _portCompleter = null;
    _portCompleterResult = null;
    _recievePort = null;
    _streamSub = null;
    _isolate = null;
  }

  Future<SendPort?> preparePortRaw({
    required void Function(dynamic result) onResult,
    required Future<void> Function(SendPort itemsSendPort) isolateFunction,
  }) async {
    if (_portCompleter != null) return await _portCompleter!.future;

    _initializingCompleter = Completer<void>(); // set early to prevent double init
    await disposePort(resetCompleter: false);
    _activePortsProviders[this] = true;
    final portCompleter = _portCompleter = Completer<SendPort?>();
    _recievePort = ReceivePort();
    void Function(dynamic) onResultVarFn;
    onResultVarFn = (result) {
      if (result is SendPort) {
        if (!portCompleter.isCompleted) portCompleter.complete(result);
        _portCompleterResult = result;
        onResultVarFn = onResult; // -- just small optimization
      } else {
        onResult(result);
      }
    };
    _streamSub = _recievePort?.listen((result) => onResultVarFn(result));
    await isolateFunction(_recievePort!.sendPort);
    return await portCompleter.future;
  }

  @protected
  void onResult(dynamic result);

  @protected
  FutureOr<IsolateFunctionReturnBuild<E>> isolateFunction(SendPort port);

  void onPreparing(bool prepared) {}

  Future<void> initialize() async {
    if (_isInitialized == true || _initializingCompleter?.isCompleted == true) return;
    if (_initializingCompleter != null) return _initializingCompleter?.future;

    _isInitialized = false;
    onPreparing(false);

    void Function(dynamic) onResultVarFn;
    onResultVarFn = (result) {
      if (result == PortsProviderMessages.prepared) {
        final initializingCompleter = _initializingCompleter;
        if (initializingCompleter != null && !initializingCompleter.isCompleted) {
          // -- before completing, other callers awaiting the completer must find it initialized.
          _isInitialized = true;
          onPreparing(true);
          initializingCompleter.complete();
        }
        onResultVarFn = onResult; // -- just small optimization
      } else {
        onResult(result);
      }
    };

    final SendPort? port;
    try {
      port = await preparePortRaw(
        onResult: (result) => onResultVarFn(result), // don't assign fn directly
        isolateFunction: (itemsSendPort) async {
          final portCompleter = _portCompleter;
          final isolateFn = await isolateFunction(itemsSendPort);
          final isolate = await Isolate.spawn(isolateFn.entryPoint, isolateFn.message, debugName: '$runtimeType');
          if (identical(portCompleter, _portCompleter)) {
            _isolate = isolate;
          } else {
            isolate.kill(priority: Isolate.immediate); // -- disposed while spawning
          }
        },
      );
    } catch (_) {
      await disposePort();
      rethrow;
    }

    if (port == null) return;
    await _initializingCompleter?.future;
  }
}

/// A [ReceivePort] paired with the [SendPort] its isolate reports back on startup.
// by claude
class PortsComm {
  final items = ReceivePort();

  final _preparedCompleter = Completer<SendPort?>();
  SendPort? _isolateSendPort;
  StreamSubscription? _subscription;
  bool _closed = false;

  /// Resolves once the isolate sent [PortsProviderMessages.prepared], or to null if [close] was called before that.
  Future<SendPort?> get sendPort => _preparedCompleter.future;

  void listen(void Function(dynamic result) onResult) {
    _subscription = items.listen((result) {
      if (result is SendPort) {
        _isolateSendPort = result;
        // -- closed while the isolate was still starting up, it can finally be disposed
        if (_closed) _disposeWith(result);
      } else if (result == PortsProviderMessages.prepared) {
        if (!_closed && !_preparedCompleter.isCompleted) _preparedCompleter.complete(_isolateSendPort);
      } else if (!_closed) {
        onResult(result);
      }
    });
  }

  void close() {
    if (_closed) return;
    _closed = true;

    // -- release whoever is waiting on it right away instead of leaving them hanging forever.
    if (!_preparedCompleter.isCompleted) _preparedCompleter.complete(null);

    // -- otherwise the isolate hasn't reported back yet, keep listening to be able to dispose it later.
    final isolateSendPort = _isolateSendPort;
    if (isolateSendPort != null) _disposeWith(isolateSendPort);
  }

  /// The isolate failed to start, so nothing will ever report back on this port.
  void abort() {
    _closed = true;
    if (!_preparedCompleter.isCompleted) _preparedCompleter.complete(null);
    _disposeWith(null);
  }

  void _disposeWith(SendPort? sendPort) {
    _subscription?.cancel();
    _subscription = null;
    items.close();
    sendPort?.send(PortsProviderMessages.disposed);
  }
}

class IsolateFunctionReturnBuild<T> {
  final void Function(T message) entryPoint;
  final T message;

  const IsolateFunctionReturnBuild(
    this.entryPoint,
    this.message,
  );
}

class IsolateMessageTokenWrapper {
  int _initial = 0;
  IsolateMessageTokenWrapper.create();

  int getToken() => _initial++;
}

/// The protocol between a [PortsProvider] or [PortsComm] and its isolate, anything else sent is a result.
enum PortsProviderMessages {
  /// Sent by the isolate once ready, after its [SendPort].
  prepared,

  /// Sent to the isolate to release its resources, or by the isolate itself when it closes on its own.
  disposed,
}
