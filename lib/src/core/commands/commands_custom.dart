// ignore_for_file: experimental_member_use

part of '../../../namico_db_wrapper.dart';

final class DBCommandsCustom extends DBCommandsBase {
  final List<DBColumnType> customTypes;
  const DBCommandsCustom(this.customTypes);

  @override
  String loadEverythingCommand(String tableName) {
    return 'SELECT * FROM $tableName';
  }

  @override
  String loadEverythingKeyedCommand(String tableName) {
    return 'SELECT * FROM $tableName';
  }

  @override
  List<String> columnNamesForRow(RawPreparedStatement st, List<String>? cached) => DBCommandsBase.readColumnNames(st, cached);

  @override
  Map<String, dynamic>? parseRow(List<String> columnNames, List<Object?> row) {
    final length = row.length;
    if (length == 0) return null;
    final map = <String, dynamic>{};
    for (int i = 0; i < length; i++) {
      map[columnNames[i]] = row[i];
    }
    return map;
  }

  @override
  DBKeyedResults? parseKeyedRow(List<String> columnNames, List<Object?> row) {
    final map = parseRow(columnNames, row);
    final key = map?['key'];
    if (key is! String) return null;
    return DBKeyedResults(
      key: key,
      map: map,
    );
  }

  @override
  bool get isWriteStatementStatic => false;

  /// Null values are skipped, so their columns are left untouched.
  @override
  List<String>? writeColumnsOf(Map<String, dynamic>? object) {
    if (object == null || object.isEmpty) return null;
    final columns = <String>[];
    for (final entry in object.entries) {
      if (entry.value != null) columns.add(entry.key);
    }
    return columns.isEmpty ? null : columns;
  }

  @override
  List<dynamic> objectToWriteParameters(String key, Map<String, dynamic>? object, List<String>? writeColumns) {
    if (writeColumns == null || object == null) return [key];
    final params = List<dynamic>.filled(writeColumns.length + 1, null);
    params[0] = key;
    for (int i = 0; i < writeColumns.length; i++) {
      params[i + 1] = object[writeColumns[i]];
    }
    return params;
  }

  @override
  String selectKeyCommand(String tableName) {
    return 'SELECT * FROM $tableName WHERE key = ?';
  }

  @override
  String selectKeysAllCommand(String tableName, int keysCount) {
    final buffer = StringBuffer('SELECT * FROM $tableName WHERE key IN');
    DBCommandsBase.writeParameterMarksInBraces(buffer, keysCount);
    return buffer.toString();
  }

  @override
  String createTableCommand(String tableName) {
    return '''
CREATE TABLE IF NOT EXISTS $tableName (
  key TEXT NOT NULL UNIQUE,
  ${customTypes.map(_typeToSQLText).join('\n  ')}
  PRIMARY KEY (key)
);
  ''';
  }

  @override
  void alterIfRequired(String tableName, Database sql) {
    final columns = sql.select('PRAGMA table_info($tableName)');
    final columnNameGetIndex = columns.columnNames.indexOf('name');
    final alreadyExistingColumns = columns.rows.map((e) => e[columnNameGetIndex] as String).toSet();
    for (int i = 0; i < customTypes.length; i++) {
      final item = customTypes[i];
      if (!alreadyExistingColumns.contains(item.name)) {
        sql.execute('ALTER TABLE $tableName ADD COLUMN ${_typeToSQLText(item, trailingComma: false)}');
      }
    }
  }

  String _typeToSQLText(DBColumnType type, {bool trailingComma = true}) {
    final buffer = StringBuffer();
    buffer.write(type.name);
    buffer.write(' ');
    buffer.write(type.type.dbText);
    if (type.nullable == false) {
      buffer.write(' NOT NULL');
    }
    if (type.defaultValue != null) {
      buffer.write(' DEFAULT ');
      buffer.write(DBCommandsBase.sqlLiteral(type.defaultValue));
    }
    if (trailingComma) buffer.write(',');
    return buffer.toString();
  }

  @override
  String writeCommand(String tableName, List<String>? writeColumns) {
    if (writeColumns == null) {
      return '''
INSERT INTO $tableName (key)
VALUES (?)
ON CONFLICT (key) DO NOTHING
  ''';
    }

    final columnsNamesBuffer = StringBuffer();
    final columnsParamsBuffer = StringBuffer();
    final conflictsBuffer = StringBuffer();
    for (int i = 0; i < writeColumns.length; i++) {
      final name = writeColumns[i];
      columnsNamesBuffer.write(', $name');
      columnsParamsBuffer.write(', ?');
      if (i > 0) conflictsBuffer.write(', ');
      conflictsBuffer.write('$name=EXCLUDED.$name');
    }

    return '''
INSERT INTO $tableName (key$columnsNamesBuffer)
VALUES (?$columnsParamsBuffer)
ON CONFLICT (key) DO UPDATE
SET $conflictsBuffer
  ''';
  }
}
