// ignore_for_file: unnecessary_overrides, unnecessary_this

part of '../namico_db_wrapper.dart';

/// A Wrapper around [DBWrapperAsync] that automatically disposes the db when not in use, and reinit when necessary.
/// The Duration is indicated by [disposeTimerDuration].
/// Disposable operations like [claimFreeSpace], [delete], [deleteBulk], [deleteEverything] will not mark the db as in use.
class _DBWrapperSyncAutoDisposable extends DBWrapperSync with _DBDisposeTimerManager {
  final Duration disposeTimerDuration;

  _DBWrapperSyncAutoDisposable._openFromInfo({
    required super.fileInfo,
    required super.config,
    required super.onClose,
    required this.disposeTimerDuration,
  }) : super._openFromInfo() {
    _rescheduleDisposeTimer();
  }

  @override
  Timer _createNewTimer() => Timer(disposeTimerDuration, super.close);

  @override
  DBWrapperSync reOpen() {
    _rescheduleDisposeTimer();
    return super.reOpen();
  }

  @override
  void _ensureDbOpen() {
    if (super.isOpen == false) {
      super.reOpen();
    }
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
  void loadEverything(LoadEverythingCallback onValue) {
    _rescheduleDisposeTimer();
    return super.loadEverything(onValue);
  }

  @override
  void loadEverythingKeyed(LoadEverythingKeyedCallback onValue) {
    _rescheduleDisposeTimer();
    return super.loadEverythingKeyed(onValue);
  }

  @override
  List<Map<String, dynamic>> loadEverythingResult() {
    _rescheduleDisposeTimer();
    return super.loadEverythingResult();
  }

  @override
  Map<String, Map<String, dynamic>> loadEverythingKeyedResult() {
    _rescheduleDisposeTimer();
    return super.loadEverythingKeyedResult();
  }

  @override
  void loadAllKeys(LoadAllKeysCallback onValue) {
    _rescheduleDisposeTimer();
    return super.loadAllKeys(onValue);
  }

  @override
  List<String> loadAllKeysResult() {
    _rescheduleDisposeTimer();
    return super.loadAllKeysResult();
  }

  @override
  void put(String key, Map<String, dynamic>? object) {
    _rescheduleDisposeTimer();
    super.put(key, object);
  }

  @override
  void putAll<E>(DBWriteList writeList) {
    _rescheduleDisposeTimer();
    super.putAll(writeList);
  }

  // ===== Methods that don't affect the timer
  @override
  void claimFreeSpace() {
    _ensureDbOpen();
    super.claimFreeSpace();
  }

  @override
  void checkpoint() {
    _ensureDbOpen();
    super.checkpoint();
  }

  @override
  void delete(String key) {
    _ensureDbOpen();
    super.delete(key);
  }

  @override
  void deleteBulk(List<String> keys) {
    _ensureDbOpen();
    return super.deleteBulk(keys);
  }

  @override
  void deleteEverything({bool claimFreeSpace = true}) {
    _ensureDbOpen();
    return super.deleteEverything(claimFreeSpace: claimFreeSpace);
  }
}

mixin _DBDisposeTimerManager {
  Timer? _disposeTimer;
  // int _currentOperations = 0;

  Timer _createNewTimer();
  void _ensureDbOpen();

  /// use on async method start
  // void _onOperationStart() {
  //   _ensureDbOpen();
  //   _currentOperations++;
  //   _cancelTimer();
  // }

  /// use on async method end
  // void _onOperationEnd() {
  //   _currentOperations--;
  //   if (_currentOperations == 0) {
  //     _rescheduleDisposeTimer();
  //   }
  // }

  /// use on sync method calls
  void _rescheduleDisposeTimer() {
    _ensureDbOpen();
    _disposeTimer?.cancel();
    _disposeTimer = _createNewTimer();
  }

  void _cancelTimer() {
    _disposeTimer?.cancel();
    _disposeTimer = null;
  }
}
