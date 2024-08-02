part of '../../namico_db_wrapper.dart';

abstract class IsolateEncodableBase {
  const IsolateEncodableBase();

  PreparedStatement buildStatement(Database sql, String tableName);
  void execute(PreparedStatement statement);
}

class IsolateEncodableClaimFreeSpace extends IsolateEncodableBase {
  const IsolateEncodableClaimFreeSpace();

  @override
  PreparedStatement buildStatement(Database sql, String tableName) {
    return sql.prepare('VACUUM'); // WHERE true
  }

  @override
  void execute(PreparedStatement statement) => statement.execute();
}

class IsolateEncodableDeleteEverything extends IsolateEncodableBase {
  const IsolateEncodableDeleteEverything();

  @override
  PreparedStatement buildStatement(Database sql, String tableName) {
    return sql.prepare('DELETE FROM $tableName'); // WHERE true
  }

  @override
  void execute(PreparedStatement statement) => statement.execute();
}

class IsolateEncodableDeleteList extends IsolateEncodableBase {
  final List<String> keys;
  const IsolateEncodableDeleteList(this.keys);

  @override
  PreparedStatement buildStatement(Database sql, String tableName) {
    final marks = keys.map((e) => '?').join(', ');
    return sql.prepare('DELETE FROM $tableName WHERE key IN($marks)');
  }

  @override
  void execute(PreparedStatement statement) {
    statement.execute(keys);
  }
}

class IsolateEncodableWriteList extends IsolateEncodableBase {
  final List<MapEntry<String, Map<String, dynamic>>> items;
  const IsolateEncodableWriteList(this.items);

  @override
  PreparedStatement buildStatement(Database sql, String tableName) {
    return DBUtils(sql, tableName).buildWriteStatement();
  }

  @override
  void execute(PreparedStatement statement) {
    items.loop((item) => statement.execute([item.key, item.value.encode()]));
  }

  static IsolateEncodableWriteList fromList<E>(List<E> items, CacheWriteItemToEntryCallback<E> itemToEntry) {
    final entries = <MapEntry<String, Map<String, dynamic>>>[];
    items.loop((e) {
      final entry = itemToEntry(e);
      entries.add(entry);
    });
    return IsolateEncodableWriteList(entries);
  }

  static IsolateEncodableWriteList fromIterable<E>(Iterable<E> items, CacheWriteItemToEntryCallback<E> itemToEntry) {
    final entries = <MapEntry<String, Map<String, dynamic>>>[];
    for (final e in items) {
      final entry = itemToEntry(e);
      entries.add(entry);
    }
    return IsolateEncodableWriteList(entries);
  }

  static IsolateEncodableWriteList fromEntry(String key, Map<String, dynamic> value) {
    final entries = <MapEntry<String, Map<String, dynamic>>>[];
    entries.add(MapEntry(key, value));
    return IsolateEncodableWriteList(entries);
  }
}
