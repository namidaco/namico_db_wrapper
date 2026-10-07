// ignore_for_file: experimental_member_use

part of '../../../namico_db_wrapper.dart';

final class DBCommands extends DBCommandsBase {
  const DBCommands();

  static final _utf8JsonEncoder = JsonUtf8Encoder(null, null, 1024);
  static final _utf8JsonDecoder = utf8.decoder.fuse(json.decoder);

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

  /// The json value is read as raw utf8 bytes, a fused utf8+json decoder on them is ~2-3x faster than `columnText` + `jsonDecode`.
  @override
  List<Object?> readRow(RawPreparedStatement st, int columnCount) {
    final row = List<Object?>.filled(columnCount, null);
    final valueType = st.columnType(0);
    if (valueType == SqlType.SQLITE_TEXT || valueType == SqlType.SQLITE_BLOB) row[0] = st.columnBlob(0);
    for (int i = 1; i < columnCount; i++) {
      row[i] = DBCommandsBase.readColumnValue(st, i);
    }
    return row;
  }

  @override
  Map<String, dynamic>? parseRow(List<String> columnNames, List<Object?> row) {
    try {
      final jsonBytes = row[0];
      if (jsonBytes is! Uint8List) return null;
      return _utf8JsonDecoder.convert(jsonBytes) as Map<String, dynamic>?;
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
  void bindWriteParameters(RawPreparedStatement st, String key, Map<String, dynamic>? object, List<String>? writeColumns) {
    st.bindText(1, key);
    if (object == null) {
      st.bindNull(2);
    } else {
      final jsonBytes = _utf8JsonEncoder.convert(object);
      st.bindBlob(2, jsonBytes);
    }
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

  /// The value is bound as utf8 bytes & cast back to TEXT, skipping a String -> utf8 conversion while keeping `json_extract` working.
  @override
  String writeCommand(String tableName, List<String>? writeColumns) {
    return '''
INSERT INTO $tableName (key, value)
VALUES (?, CAST(? AS TEXT))
ON CONFLICT (key) DO UPDATE
SET value=EXCLUDED.value
  ''';
  }
}
