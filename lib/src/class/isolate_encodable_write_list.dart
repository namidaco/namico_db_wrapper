part of '../../namico_db_wrapper.dart';

abstract class IsolateEncodableBase {
  const IsolateEncodableBase();

  PreparedStatement buildStatement(Database sql, String tableName, {required DBCommandsBase commands});
  void execute(PreparedStatement statement, {required DBCommandsBase commands});
}

class IsolateEncodableClaimFreeSpace extends IsolateEncodableBase {
  const IsolateEncodableClaimFreeSpace();

  @override
  PreparedStatement buildStatement(Database sql, String tableName, {required DBCommandsBase commands}) {
    return sql.prepare('VACUUM');
  }

  @override
  void execute(PreparedStatement statement, {required DBCommandsBase commands}) => statement.execute();
}

class IsolateEncodableDeleteEverything extends IsolateEncodableBase {
  const IsolateEncodableDeleteEverything();

  @override
  PreparedStatement buildStatement(Database sql, String tableName, {required DBCommandsBase commands}) {
    return sql.prepare('DELETE FROM $tableName', persistent: true); // WHERE true
  }

  @override
  void execute(PreparedStatement statement, {required DBCommandsBase commands}) => statement.execute();
}

class IsolateEncodableDeleteList extends IsolateEncodableBase {
  final List<String> keys;
  const IsolateEncodableDeleteList(this.keys);

  @override
  PreparedStatement buildStatement(Database sql, String tableName, {required DBCommandsBase commands}) {
    final buffer = StringBuffer('DELETE FROM $tableName WHERE key IN');
    DBCommandsBase.writeParameterMarksInBraces(buffer, keys.length);
    return sql.prepare(buffer.toString(), persistent: true);
  }

  @override
  void execute(PreparedStatement statement, {required DBCommandsBase commands}) {
    statement.execute(keys);
  }
}

class IsolateEncodableWriteList extends IsolateEncodableBase {
  final List<MapEntry<String, Map<String, dynamic>?>> items;
  final Iterable<String>? keys;
  const IsolateEncodableWriteList(this.items, this.keys);

  @override
  PreparedStatement buildStatement(Database sql, String tableName, {required DBCommandsBase commands}) {
    return _DBCommandsManager(sql, tableName, commands).buildWriteStatement(keys);
  }

  @override
  void execute(PreparedStatement statement, {required DBCommandsBase commands}) {
    items.loop((item) => statement.execute(commands.objectToWriteParameters(item.key, item.value)));
  }

  static IsolateEncodableWriteList fromList<E>(List<E> items, CacheWriteItemToEntryCallback<E> itemToEntry) {
    final entries = <MapEntry<String, Map<String, dynamic>?>>[];
    final keys = <String>{};
    items.loop((e) {
      final entry = itemToEntry(e);
      entries.add(entry);
      final subkeys = entry.value?.keys;
      if (subkeys != null) keys.addAll(subkeys);
    });
    return IsolateEncodableWriteList(entries, keys);
  }

  static IsolateEncodableWriteList fromIterable<E>(Iterable<E> items, CacheWriteItemToEntryCallback<E> itemToEntry) {
    final entries = <MapEntry<String, Map<String, dynamic>?>>[];
    final keys = <String>{};
    for (final e in items) {
      final entry = itemToEntry(e);
      entries.add(entry);
      final subkeys = entry.value?.keys;
      if (subkeys != null) keys.addAll(subkeys);
    }
    return IsolateEncodableWriteList(entries, keys);
  }

  static IsolateEncodableWriteList fromEntry(String key, Map<String, dynamic>? value) {
    return IsolateEncodableWriteList([MapEntry(key, value)], value?.keys);
  }
}
