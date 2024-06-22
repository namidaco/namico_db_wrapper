part of '../namico_db_wrapper.dart';

class DBCore {
  /// Opens a database in read-only mode syncronously
  static T readDatabaseSync<T>(String dbFilePath, T Function(Database db) callback) {
    sqlopen.open.overrideFor(sqlopen.OperatingSystem.android, sqlcipher.openCipherOnAndroid);
    final db = sqlite3.open(dbFilePath, mode: OpenMode.readOnly);
    try {
      return callback(db);
    } finally {
      db.dispose();
    }
  }
}
