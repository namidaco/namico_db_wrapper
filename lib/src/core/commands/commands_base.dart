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
  List<dynamic> objectToWriteParameters(String key, Map<String, dynamic>? object);

  String createTableCommand(String tableName);
  String selectKeyCommand(String tableName);
  String doesKeyExistCommand(String tableName) => 'SELECT 1 FROM $tableName WHERE key IN (?)';
  String writeCommand(String tableName, Iterable<String>? keys);
  String vacuumCommand() => 'VACUUM';

  /// Alters the table by adding columns if required.
  void alterIfRequired(String tableName, Database sql);
}
