part of '../namico_db_wrapper.dart';

class DBCoreFunctions {
  /// Opens a database in read-only mode syncronously
  static T readDatabaseSync<T>(String dbFilePath, T Function(Database db) callback) {
    NamicoDBWrapper.initialize();
    final db = sqlite3.open(dbFilePath, mode: OpenMode.readOnly);
    try {
      return callback(db);
    } finally {
      db.dispose();
    }
  }
}
