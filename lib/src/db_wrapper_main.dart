part of '../namico_db_wrapper.dart';

/// A Manager for group of databases in a specific directroy.
class DBWrapperMain {
  final String _defaultDirectory;
  final Duration? autoDisposeTimerDuration;
  final void Function(DBWrapper db)? onFirstOpen;

  /// Initialize a databases manager for a directory.
  DBWrapperMain(
    this._defaultDirectory, {
    this.onFirstOpen,
    this.autoDisposeTimerDuration = _DBWrapperAutoDisposable.defaultDisposeTimerDuration,
  });

  final _openDB = <String, DBWrapper>{};

  /// opens a new db or returns the already opened one. see [DBWrapper.open] for internal implementation
  DBWrapper getDB(
    String dbName, {
    String? encryptionKey,
    bool createIfNotExist = false,
    List<DBColumnType>? customTypes,
    Duration? autoDisposeTimerDuration = _DBWrapperAutoDisposable.defaultDisposeTimerDuration,
  }) {
    final box = _openDB[dbName];
    if (box != null && box.isOpen) return box;

    final dir = _defaultDirectory;
    final newDB = DBWrapper.open(
      dir,
      dbName,
      encryptionKey: encryptionKey,
      createIfNotExist: createIfNotExist,
      customTypes: customTypes,
      autoDisposeTimerDuration: autoDisposeTimerDuration ?? this.autoDisposeTimerDuration,
    );
    _openDB[dbName] = newDB;
    if (onFirstOpen != null) onFirstOpen!(newDB);
    return newDB;
  }

  /// Close a db by [dbName].
  void close(String dbName) => _openDB[dbName]?.close();

  /// Close all databases in [_defaultDirectory] specified by [DBWrapperMain.init].
  void closeAll() {
    final boxes = _openDB.values.toList();
    _openDB.clear();
    boxes.loop((item) => item.close());
  }
}
