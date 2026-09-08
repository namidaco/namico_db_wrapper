// ignore_for_file: experimental_member_use

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
  List<String> columnNamesForRow(RawPreparedStatement st, List<String>? cached) => const [];

  @override
  Map<String, dynamic>? parseRow(List<String> columnNames, List<Object?> row) {
    try {
      final jsonString = row[0];
      if (jsonString is! String) return null;
      return jsonDecode(jsonString) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  @override
  DBKeyedResults? parseKeyedRow(List<String> columnNames, List<Object?> row) {
    final resmap = parseRow(columnNames, row);
    final key = row[1] as String;
    return DBKeyedResults(
      key: key,
      map: resmap,
    );
  }

  @override
  bool get isWriteStatementStatic => true;

  @override
  List<String>? writeColumnsOf(Map<String, dynamic>? object) => null;

  @override
  List<dynamic> objectToWriteParameters(String key, Map<String, dynamic>? object, List<String>? writeColumns) {
    return [key, object == null ? null : jsonEncode(object)];
  }

  @override
  String selectKeyCommand(String tableName) {
    return 'SELECT value FROM $tableName WHERE key = ?';
  }

  @override
  String selectKeysAllCommand(String tableName, int keysCount) {
    final buffer = StringBuffer('SELECT value FROM $tableName WHERE key IN');
    DBCommandsBase.writeParameterMarksInBraces(buffer, keysCount);
    return buffer.toString();
  }

  @override
  String createTableCommand(String tableName) {
    return '''
CREATE TABLE IF NOT EXISTS $tableName (
  key TEXT NOT NULL UNIQUE,
  value TEXT,
  PRIMARY KEY (key)
);
  ''';
  }

  @override
  void alterIfRequired(String tableName, Database sql) {}

  @override
  String writeCommand(String tableName, List<String>? writeColumns) {
    return '''
INSERT INTO $tableName (key, value)
VALUES (?, ?)
ON CONFLICT (key) DO UPDATE
SET value=EXCLUDED.value
  ''';
  }
}
