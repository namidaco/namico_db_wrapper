part of '../../../namico_db_wrapper.dart';

final class DBCommands extends DBCommandsBase {
  const DBCommands();

  @override
  String loadEverythingCommand(String tableName) {
    return 'SELECT value FROM $tableName';
  }

  @override
  String loadEverythingKeyedCommand(String tableName) {
    return 'SELECT value,key FROM $tableName';
  }

  @override
  Map<String, dynamic>? parseResults(ResultSet result) {
    try {
      return jsonDecode(result.first as String) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }

  @override
  DBKeyedResults parseKeyedResults(ResultSet result) {
    final resmap = parseResults(result);
    final key = result.rows[1] as String;
    return DBKeyedResults(
      key: key,
      map: resmap,
    );
  }

  @override
  List<dynamic> objectToWriteParameters(String key, Map<String, dynamic> object) {
    return [key, jsonEncode(object)];
  }

  @override
  String selectKeyCommand(String tableName) {
    return 'SELECT value FROM $tableName WHERE key IN (?)';
  }

  @override
  String createTableCommand(String tableName) {
    return '''
CREATE TABLE IF NOT EXISTS $tableName (
  key TEXT NOT NULL UNIQUE,
  value TEXT NOT NULL,
  PRIMARY KEY (key)
);
  ''';
  }

  @override
  void alterIfRequired(String tableName, Database sql) {}

  @override
  String writeCommand(String tableName, Iterable<String>? keys) {
    return '''
INSERT INTO $tableName (key, value)
VALUES (?, ?)
ON CONFLICT (key) DO UPDATE
SET value=EXCLUDED.value
  ''';
  }
}
