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
  Map<String, dynamic>? parseRow(List<String> columnNames, List<Object?> row) {
    final map = <String, dynamic>{};
    final columns = columnNames;
    for (int i = 0; i < row.length; i++) {
      var value = row[i];
      var columnName = columns[i];
      map[columnName] = value;
    }
    if (map.isEmpty) return null;
    return map;
  }

  @override
  DBKeyedResults? parseKeyedRow(List<String> columnNames, List<Object?> row) {
    final resmap = parseRow(columnNames, row);
    if (resmap == null) return null;
    final key = resmap['key'] as String?;
    if (key == null) return null;
    return DBKeyedResults(
      key: key,
      map: resmap,
    );
  }

  @override
  List<dynamic> objectToWriteParameters(String key, Map<String, dynamic>? object) {
    final params = <dynamic>[key];
    if (object == null) return params;

    customTypes.loop(
      (item) {
        final value = object[item.name];
        if (value != null) params.add(value);
      },
    );
    return params;
  }

  @override
  String selectKeyCommand(String tableName) {
    return 'SELECT * FROM $tableName WHERE key IN (?)';
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
    final columnNameGetIndex = columns.columnNames.indexWhere((element) => element == 'name');
    final alreadyExistingColumns = columns.rows.map((e) => e[columnNameGetIndex] as String).toSet();
    for (int i = 0; i < customTypes.length; i++) {
      var item = customTypes[i];
      final requiredColumnName = item.name;
      if (!alreadyExistingColumns.contains(requiredColumnName)) {
        final nullableText = item.nullable ? '' : ' NOT NULL';
        final defaultValueText = item.defaultValue == null ? '' : ' DEFAULT `${item.defaultValue}`';
        sql.execute('ALTER TABLE $tableName ADD COLUMN $requiredColumnName ${item.type.dbText}$nullableText$defaultValueText');
      }
    }
  }

  String _typeToSQLText(DBColumnType type) {
    var buffer = StringBuffer();
    buffer.write(type.name);
    buffer.write(' ');
    buffer.write(type.type.dbText);
    if (type.nullable == false) {
      buffer.write(' NOT NULL');
    }
    if (type.defaultValue != null) {
      buffer.write(' DEFAULT `${type.defaultValue}`');
    }
    buffer.write(',');
    return buffer.toString();
  }

  @override
  String writeCommand(String tableName, Iterable<String>? keys) {
    if (keys == null) {
      // insert key only if no column keys provided
      return '''
INSERT INTO $tableName (key)
VALUES (?)
  ''';
    }

    final columnsNamesBuffer = StringBuffer();
    final columnsParamsBuffer = StringBuffer();
    final conflictsBuffer = StringBuffer();
    bool isFirst = true;
    for (final name in keys) {
      columnsNamesBuffer.write(', $name');
      columnsParamsBuffer.write(', ?');
      if (!isFirst) conflictsBuffer.write(', ');
      conflictsBuffer.write('$name=EXCLUDED.$name');
      isFirst = false;
    }

    return '''
INSERT INTO $tableName (key${columnsNamesBuffer.toString()})
VALUES (?${columnsParamsBuffer.toString()})
ON CONFLICT (key) DO UPDATE
SET ${conflictsBuffer.toString()}
  ''';
  }
}
