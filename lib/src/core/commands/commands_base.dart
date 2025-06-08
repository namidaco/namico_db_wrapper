part of '../../../namico_db_wrapper.dart';

/// Commands builder interface. See [DBCommands] & [DBCommandsCustom].
abstract interface class DBCommandsBase {
  const DBCommandsBase();

  factory DBCommandsBase.dynamic(List<DBColumnType>? customTypes) {
    return customTypes == null ? DBCommands() : DBCommandsCustom(customTypes);
  }

  String loadEverythingCommand(String tableName);
  String loadEverythingKeyedCommand(String tableName);

  Map<String, dynamic>? parseRow(List<String> columnNames, List<Object?> row);
  DBKeyedResults? parseKeyedRow(List<String> columnNames, List<Object?> row);
  String? parseKeyFromRow(List<Object?> row) => row[0]?.toString();
  List<dynamic> objectToWriteParameters(String key, Map<String, dynamic>? object);

  String createTableCommand(String tableName);
  String selectKeyCommand(String tableName);
  String selectKeysAllCommand(String tableName, int keysCount);
  String selectAllKeysCommand(String tableName) => 'SELECT key FROM $tableName';
  String doesKeyExistCommand(String tableName) => 'SELECT 1 FROM $tableName WHERE key IN (?)';
  String writeCommand(String tableName, Iterable<String>? keys);
  String deleteCommand(String tableName, List<String> keys) {
    final buffer = StringBuffer('DELETE FROM $tableName WHERE key IN');
    DBCommandsBase.writeParameterMarksInBraces(buffer, keys.length);
    return buffer.toString();
  }

  String deleteEverythingCommand(String tableName) => 'DELETE FROM $tableName';

  String vacuumCommand() => 'VACUUM';
  String checkpointCommand() => 'PRAGMA wal_checkpoint';

  /// Alters the table by adding columns if required.
  void alterIfRequired(String tableName, Database sql);

  static void writeParameterMarksInBraces(StringBuffer buffer, int count) {
    buffer.write(' (');
    while (count > 1) {
      buffer.write('?, ');
      count--;
    }
    buffer.write('?');
    buffer.write(')');
  }
}
