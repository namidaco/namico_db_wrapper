part of '../../namico_db_wrapper.dart';

class DBWriteList {
  final List<MapEntry<String, Map<String, dynamic>?>> items;
  const DBWriteList(this.items);

  static DBWriteList fromList<E>(List<E> items, CacheWriteItemToEntryCallback<E> itemToEntry) {
    final entries = <MapEntry<String, Map<String, dynamic>?>>[];
    final keys = <String>{};
    for (int i = 0; i < items.length; i++) {
      final e = items[i];
      final entry = itemToEntry(e);
      entries.add(entry);
      final subkeys = entry.value?.keys;
      if (subkeys != null) keys.addAll(subkeys);
    }
    return DBWriteList(entries);
  }

  static DBWriteList fromIterable<E>(Iterable<E> items, CacheWriteItemToEntryCallback<E> itemToEntry) {
    final entries = <MapEntry<String, Map<String, dynamic>?>>[];
    final keys = <String>{};
    for (final e in items) {
      final entry = itemToEntry(e);
      entries.add(entry);
      final subkeys = entry.value?.keys;
      if (subkeys != null) keys.addAll(subkeys);
    }
    return DBWriteList(entries);
  }

  static DBWriteList fromEntry(String key, Map<String, dynamic>? value) {
    return DBWriteList([MapEntry(key, value)]);
  }
}
