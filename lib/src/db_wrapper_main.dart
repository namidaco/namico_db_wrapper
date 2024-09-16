part of '../namico_db_wrapper.dart';

class DBWrapperMain {
  final String _defaultDirectory;
  final void Function(DBWrapper db)? onFirstOpen;
  DBWrapperMain.init(this._defaultDirectory, {this.onFirstOpen}) {
    sqlopen.open.overrideFor(sqlopen.OperatingSystem.android, sqlcipher.openCipherOnAndroid);
  }

  final _openDB = <String, DBWrapper>{};

  DBWrapper open(String boxName, {String? encryptionKey, bool createIfNotExist = false}) {
    final box = _openDB[boxName];
    if (box != null && box.isOpen) return box;

    final dir = _defaultDirectory;
    final newBox = DBWrapper.open(dir, boxName, encryptionKey: encryptionKey, createIfNotExist: createIfNotExist);
    _openDB[boxName] = newBox;
    if (onFirstOpen != null) onFirstOpen!(newBox);
    return newBox;
  }

  void close(String boxName) => _openDB[boxName]?.close();

  void closeAll() {
    final boxes = _openDB.values.toList();
    _openDB.clear();
    boxes.loop((item) => item.close());
  }
}
