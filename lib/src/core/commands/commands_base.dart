// ignore_for_file: experimental_member_use

part of '../../../namico_db_wrapper.dart';

/// Commands builder interface. See [DBCommands] & [DBCommandsCustom].
abstract interface class DBCommandsBase {
  const DBCommandsBase();

  factory DBCommandsBase.dynamic(List<DBColumnType>? customTypes) {
    return customTypes == null ? const DBCommands() : DBCommandsCustom(customTypes);
  }

  /// Max number of `?` parameters per statement, kept under the legacy `SQLITE_MAX_VARIABLE_NUMBER` limit.
  static const int maxParametersPerStatement = 999;

  String loadEverythingCommand(String tableName);
  String loadEverythingKeyedCommand(String tableName);

  /// Selects `key` followed by `json_extract(value, path)` for each path in [jsonPaths].
  String loadEverythingExtractedCommand(String tableName, List<String> jsonPaths) {
    final buffer = StringBuffer('SELECT key');
    for (final path in jsonPaths) {
      buffer.write(", json_extract(value, '");
      buffer.write(path);
      buffer.write("')");
    }
    buffer.write(' FROM ');
    buffer.write(tableName);
    return buffer.toString();
  }

  /// Column names needed by [parseRow]. Must be called after a successful step.
  /// [cached] is reused when the statement column count didn't change.
  List<String> columnNamesForRow(RawPreparedStatement st, List<String>? cached);

  Map<String, dynamic>? parseRow(List<String> columnNames, List<Object?> row);
  DBKeyedResults? parseKeyedRow(List<String> columnNames, List<Object?> row);

  /// Whether the write statement is the same for every object, in which case it can be prepared once.
  bool get isWriteStatementStatic;

  /// The columns (except `key`) that will be written for [object], in the same order as [objectToWriteParameters].
  List<String>? writeColumnsOf(Map<String, dynamic>? object);

  List<dynamic> objectToWriteParameters(String key, Map<String, dynamic>? object, List<String>? writeColumns);

  String createTableCommand(String tableName);
  String selectKeyCommand(String tableName);
  String selectKeysAllCommand(String tableName, int keysCount);
  String selectAllKeysCommand(String tableName) => 'SELECT key FROM $tableName';
  String doesKeyExistCommand(String tableName) => 'SELECT 1 FROM $tableName WHERE key = ?';
  String writeCommand(String tableName, List<String>? writeColumns);
  String deleteCommand(String tableName, int keysCount) {
    final buffer = StringBuffer('DELETE FROM $tableName WHERE key IN');
    DBCommandsBase.writeParameterMarksInBraces(buffer, keysCount);
    return buffer.toString();
  }

  String deleteEverythingCommand(String tableName) => 'DELETE FROM $tableName';

  String vacuumCommand() => 'VACUUM';
  String checkpointCommand() => 'PRAGMA wal_checkpoint(TRUNCATE)';

  /// Alters the table by adding columns if required.
  void alterIfRequired(String tableName, Database sql);

  static void writeParameterMarksInBraces(StringBuffer buffer, int count) {
    buffer.write(' (?');
    for (int i = 1; i < count; i++) {
      buffer.write(', ?');
    }
    buffer.write(')');
  }

  static List<String> readColumnNames(RawPreparedStatement st, List<String>? cached) {
    final count = st.columnCount;
    if (cached != null && cached.length == count) return cached;
    return List<String>.generate(count, st.columnName, growable: false);
  }

  /// Reads the current row of [st] into a list. Must be called after a successful step.
  static List<Object?> readRawRow(RawPreparedStatement st, int columnCount) {
    final row = List<Object?>.filled(columnCount, null);
    for (int i = 0; i < columnCount; i++) {
      row[i] = readColumnValue(st, i);
    }
    return row;
  }

  static Object? readColumnValue(RawPreparedStatement st, int index) {
    final type = st.columnType(index);
    if (type == SqlType.SQLITE_TEXT) return st.columnText(index);
    if (type == SqlType.SQLITE_INTEGER) return st.columnInt64(index);
    if (type == SqlType.SQLITE_NULL) return null;
    if (type == SqlType.SQLITE_FLOAT) return st.columnDouble(index);
    if (type == SqlType.SQLITE_BLOB) return st.columnBlob(index);
    return null;
  }

  static String sqlLiteral(Object? value) {
    if (value is String) return "'${value.replaceAll("'", "''")}'";
    if (value == null) return 'NULL';
    if (value is bool) return value ? '1' : '0';
    if (value is num) return value.toString();
    return "'${value.toString().replaceAll("'", "''")}'";
  }
}
