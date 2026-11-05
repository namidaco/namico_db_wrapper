// by claude
part of '../namico_db_wrapper.dart';

/// A [DBWrapperAsync] that holds single [put] & [delete] calls for [batchDelay], then sends them as one transaction.
/// Every other call sends the held writes first, and the db isolate runs calls in order, so reads always see them.
class _DBWrapperAsyncBatched extends DBWrapperAsync {
  final Duration batchDelay;

  _DBWrapperAsyncBatched._openFromInfo({
    required super.fileInfo,
    required super.config,
    required this.batchDelay,
  }) : super._openFromInfo() {
    // -- app exit & [NamicoDBWrapper.suspend] dispose the isolate without [close]
    _isolateManager.onDisposing = _sendPending;
  }

  static const _kMaxPending = 200;

  final _pendingPuts = <String, Map<String, dynamic>?>{};
  final _pendingDeletes = <String>{};
  Completer<List<void>>? _pendingWritten;
  Timer? _sendTimer;

  @override
  Future<void> put(String key, Map<String, dynamic>? object) {
    _pendingDeletes.remove(key);
    _pendingPuts[key] = object;
    return _schedulePending();
  }

  @override
  Future<void> delete(String key) {
    _pendingPuts.remove(key);
    _pendingDeletes.add(key);
    return _schedulePending();
  }

  Future<void> _schedulePending() {
    final pendingWritten = _pendingWritten ??= Completer<List<void>>();
    final pendingCount = _pendingPuts.length + _pendingDeletes.length;
    if (pendingCount >= _kMaxPending) {
      _sendPending();
    } else {
      _sendTimer ??= Timer(batchDelay, _sendPending);
    }
    return pendingWritten.future;
  }

  /// puts & deletes never share a key, so their order doesn't matter.
  void _sendPending() {
    _sendTimer?.cancel();
    _sendTimer = null;
    final pendingWritten = _pendingWritten;
    if (pendingWritten == null) return;
    _pendingWritten = null;

    final sentFutures = <Future<void>>[];
    if (_pendingDeletes.isNotEmpty) {
      final deleteKeys = _pendingDeletes.toList(growable: false);
      _pendingDeletes.clear();
      sentFutures.add(super.deleteBulk(deleteKeys));
    }
    if (_pendingPuts.isNotEmpty) {
      final putEntries = _pendingPuts.entries.toList(growable: false);
      _pendingPuts.clear();
      final putsList = DBWriteList(putEntries);
      sentFutures.add(_writeAsync(putsList));
    }

    final batchWritten = Future.wait(sentFutures);
    pendingWritten.complete(batchWritten);
  }

  @override
  Future<void> putAll<E>(List<E> items, CacheWriteItemToEntryCallback<E> itemToEntry) {
    _sendPending();
    return super.putAll(items, itemToEntry);
  }

  @override
  Future<void> putAllIterable<E>(Iterable<E> items, CacheWriteItemToEntryCallback<E> itemToEntry) {
    _sendPending();
    return super.putAllIterable(items, itemToEntry);
  }

  @override
  Future<void> putAllIterableIfAbsent<E>(Iterable<E> items, CacheWriteItemToEntryCallback<E> itemToEntry) {
    _sendPending();
    return super.putAllIterableIfAbsent(items, itemToEntry);
  }

  @override
  Future<void> deleteBulk(List<String> keys) {
    _sendPending();
    return super.deleteBulk(keys);
  }

  @override
  Future<void> deleteEverything({bool claimFreeSpaceAndCheckpoint = true}) {
    _sendPending();
    return super.deleteEverything(claimFreeSpaceAndCheckpoint: claimFreeSpaceAndCheckpoint);
  }

  @override
  Future<void> claimFreeSpaceAndCheckpoint() {
    _sendPending();
    return super.claimFreeSpaceAndCheckpoint();
  }

  @override
  Future<void> checkpoint() {
    _sendPending();
    return super.checkpoint();
  }

  @override
  Future<List<Map<String, dynamic>>> loadEverythingResult() {
    _sendPending();
    return super.loadEverythingResult();
  }

  @override
  Future<Map<String, Map<String, dynamic>>> loadEverythingKeyedResult() {
    _sendPending();
    return super.loadEverythingKeyedResult();
  }

  @override
  Future<List<String>> loadAllKeysResult() {
    _sendPending();
    return super.loadAllKeysResult();
  }

  @override
  Future<bool> containsKey(String key) {
    _sendPending();
    return super.containsKey(key);
  }

  @override
  Future<Map<String, dynamic>?> get(String key) {
    _sendPending();
    return super.get(key);
  }

  @override
  Future<List<Map<String, dynamic>>> getAll(List<String> keys) {
    _sendPending();
    return super.getAll(keys);
  }

  @override
  Future<List<Object?>?> getExtracted(String key, List<String> jsonPaths) {
    _sendPending();
    return super.getExtracted(key, jsonPaths);
  }

  @override
  Future<Map<String, List<Object?>>> getAllExtractedResult(List<String> keys, List<String> jsonPaths) {
    _sendPending();
    return super.getAllExtractedResult(keys, jsonPaths);
  }

  /// closing kills the isolate, so held writes must land first.
  @override
  Future<void> close() async {
    final pendingWritten = _pendingWritten;
    _sendPending();
    if (pendingWritten != null) {
      try {
        await pendingWritten.future;
      } catch (_) {
        // -- the write callers get it
      }
    }
    return super.close();
  }
}
