// ignore_for_file: unnecessary_overrides

part of '../namico_db_wrapper.dart';

/// A Wrapper [DBWrapper] that automatically dispose the db when not in use, and reinit when necessary.
/// The Duration is indicated by [disposeTimerDuration].
/// Disposable operations like [claimFreeSpace], [claimFreeSpaceAsync], [delete], [deleteAsync], [deleteEverything] will not mark the db as in use.
class _DBWrapperAutoDisposable extends DBWrapper {
  static const defaultDisposeTimerDuration = Duration(minutes: 5);

  final Duration disposeTimerDuration;

  _DBWrapperAutoDisposable._openFromInfo({
    required super.fileInfo,
    super.encryptionKey,
    super.createIfNotExist,
    super.customTypes,
    required this.disposeTimerDuration,
  }) : super._openFromInfo() {
    _rescheduleDisposeTimer();
  }

  Timer? _disposeTimer;
  int _currentOperations = 0;

  /// use on async method start
  void _onOperationStart() {
    if (super.isOpen == false) {
      super.reOpen();
    }
    _currentOperations++;
    _cancelTimer();
  }

  /// use on async method end
  void _onOperationEnd() {
    _currentOperations--;
    if (_currentOperations == 0) {
      _rescheduleDisposeTimer();
    }
  }

  /// use on sync method calls
  void _rescheduleDisposeTimer() {
    if (super.isOpen == false) {
      super.reOpen();
    }
    _disposeTimer?.cancel();
    _disposeTimer = Timer(disposeTimerDuration, super.close);
  }

  void _cancelTimer() {
    _disposeTimer?.cancel();
    _disposeTimer = null;
  }

  @override
  void close() {
    _cancelTimer();
    super.close();
  }

  @override
  bool containsKey(String key) {
    _rescheduleDisposeTimer();
    return super.containsKey(key);
  }

  @override
  Map<String, dynamic>? get(String key) {
    _rescheduleDisposeTimer();
    return super.get(key);
  }

  @override
  List<Map<String, dynamic>> getAll(List<String> keys) {
    _rescheduleDisposeTimer();
    return super.getAll(keys);
  }

  @override
  Future<List<Map<String, dynamic>>> getAllAsync(List<String> keys) async {
    _onOperationStart();
    final val = await super.getAllAsync(keys);
    _onOperationEnd();
    return val;
  }

  @override
  Future<Map<String, dynamic>?> getAsync(String key) async {
    _onOperationStart();
    final val = await super.getAsync(key);
    _onOperationEnd();
    return val;
  }

  @override
  void loadEverything(void Function(Map<String, dynamic> value) onValue) {
    _rescheduleDisposeTimer();
    return super.loadEverything(onValue);
  }

  @override
  void loadEverythingKeyed(void Function(String key, Map<String, dynamic> value) onValue) {
    _rescheduleDisposeTimer();
    return super.loadEverythingKeyed(onValue);
  }

  @override
  Future<void> prepareIsolateChannel() async {
    _onOperationStart();
    await super.prepareIsolateChannel();
    _onOperationEnd();
  }

  @override
  void put(String key, Map<String, dynamic>? object) {
    _rescheduleDisposeTimer();
    super.put(key, object);
  }

  @override
  Future<void> putAllAsync<E>(List<E> items, CacheWriteItemToEntryCallback<E> itemToEntry) async {
    _onOperationStart();
    await super.putAllAsync(items, itemToEntry);
    _onOperationEnd();
  }

  @override
  Future<void> putAllIterableAsync<E>(Iterable<E> items, CacheWriteItemToEntryCallback<E> itemToEntry) async {
    _onOperationStart();
    await super.putAllIterableAsync(items, itemToEntry);
    _onOperationEnd();
  }

  @override
  Future<void> putAsync(String key, Map<String, dynamic>? object) async {
    _onOperationStart();
    await super.putAsync(key, object);
    _onOperationEnd();
  }

  // ===== Methods that don't affect the timer
  @override
  void claimFreeSpace() => super.claimFreeSpace();

  @override
  Future<void> claimFreeSpaceAsync() => super.claimFreeSpaceAsync();

  @override
  void delete(String key) => super.delete(key);

  @override
  Future<void> deleteAsync(String key) => super.deleteAsync(key);

  @override
  Future<void> deleteEverything() => super.deleteEverything();
}
