part of '../../namico_db_wrapper.dart';

class DBWriteList {
  final List<MapEntry<String, Map<String, dynamic>?>> items;
  const DBWriteList(this.items);

  static DBWriteList fromList<E>(List<E> items, CacheWriteItemToEntryCallback<E> itemToEntry) {
    final entries = List<MapEntry<String, Map<String, dynamic>?>>.generate(items.length, (i) => itemToEntry(items[i]), growable: false);
    return DBWriteList(entries);
  }

  static DBWriteList fromIterable<E>(Iterable<E> items, CacheWriteItemToEntryCallback<E> itemToEntry) {
    final entries = <MapEntry<String, Map<String, dynamic>?>>[];
    for (final e in items) {
      entries.add(itemToEntry(e));
    }
    return DBWriteList(entries);
  }

  static DBWriteList fromEntry(String key, Map<String, dynamic>? value) {
    return DBWriteList([MapEntry(key, value)]);
  }
}
