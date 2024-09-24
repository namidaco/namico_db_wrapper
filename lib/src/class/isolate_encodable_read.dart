part of '../../namico_db_wrapper.dart';

class IsolateEncodableReadKey extends IsolateEncodableBase {
  final String key;
  const IsolateEncodableReadKey(this.key);

  @override
  PreparedStatement buildStatement(Database sql, String tableName, {required DBCommandsBase commands}) {
    final command = commands.selectKeyCommand(tableName);
    return sql.prepare(command);
  }

  @override
  Map<String, dynamic>? execute(PreparedStatement statement, {required DBCommandsBase commands}) {
    final res = statement.select([key]);
    final row = res.rows.firstOrNull;
    if (row == null) return null;
    final columnNames = res.columnNames;
    try {
      return commands.parseRow(columnNames, row);
    } catch (_) {
      return null;
    }
  }
}

class IsolateEncodableReadList extends IsolateEncodableBase {
  final List<String> keys;
  const IsolateEncodableReadList(this.keys);

  @override
  PreparedStatement buildStatement(Database sql, String tableName, {required DBCommandsBase commands}) {
    final command = commands.selectKeysAllCommand(tableName, keys.length);
    return sql.prepare(command);
  }

  @override
  List<Map<String, dynamic>> execute(PreparedStatement statement, {required DBCommandsBase commands}) {
    final res = statement.select(keys);
    final values = <Map<String, dynamic>>[];
    final columnNames = res.columnNames;
    res.rows.loop(
      (row) {
        final parsed = commands.parseRow(columnNames, row);
        if (parsed != null) values.add(parsed);
      },
    );
    return values;
  }
}
