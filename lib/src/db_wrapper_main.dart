part of '../namico_db_wrapper.dart';

/// A Manager for group of databases in a specific directroy.
class DBWrapperMain {
  final String _defaultDirectory;
  final void Function(DBWrapper db)? onFirstOpen;

  /// Initialize a databases manager for a directory.
  DBWrapperMain.init(this._defaultDirectory, {this.onFirstOpen}) {
    sqlopen.open.overrideFor(sqlopen.OperatingSystem.android, sqlcipher.openCipherOnAndroid);
  }

  final _openDB = <String, DBWrapper>{};

  /// opens a new db or returns the already opened one. see [DBWrapper.open] for internal implementation
  DBWrapper getDB(String dbName, {String? encryptionKey, bool createIfNotExist = false, List<DBColumnType>? customTypes}) {
    final box = _openDB[dbName];
    if (box != null && box.isOpen) return box;

    final dir = _defaultDirectory;
    final newBox = DBWrapper.open(dir, dbName, encryptionKey: encryptionKey, createIfNotExist: createIfNotExist, customTypes: customTypes);
    _openDB[dbName] = newBox;
    if (onFirstOpen != null) onFirstOpen!(newBox);
    return newBox;
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
