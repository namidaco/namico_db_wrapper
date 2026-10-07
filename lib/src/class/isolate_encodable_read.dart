part of '../../namico_db_wrapper.dart';

class _IsolateEncodableContainsKey extends _IsolateEncodable {
  final String key;
  const _IsolateEncodableContainsKey(this.key);

  @override
  bool execute(DBWrapperSync db) => db.containsKey(key);
}

class _IsolateEncodableReadKey extends _IsolateEncodable {
  final String key;
  const _IsolateEncodableReadKey(this.key);

  @override
  Map<String, dynamic>? execute(DBWrapperSync db) => db.get(key);
}

class _IsolateEncodableReadList extends _IsolateEncodable {
  final List<String> keys;
  const _IsolateEncodableReadList(this.keys);

  @override
  List<Map<String, dynamic>> execute(DBWrapperSync db) => db.getAll(keys);
}

class _IsolateEncodableReadKeyExtracted extends _IsolateEncodable {
  final String key;
  final List<String> jsonPaths;
  const _IsolateEncodableReadKeyExtracted(this.key, this.jsonPaths);

  @override
  List<Object?>? execute(DBWrapperSync db) => db.getExtracted(key, jsonPaths);
}

class _IsolateEncodableReadListExtracted extends _IsolateEncodable {
  final List<String> keys;
  final List<String> jsonPaths;
  const _IsolateEncodableReadListExtracted(this.keys, this.jsonPaths);

  @override
  Map<String, List<Object?>> execute(DBWrapperSync db) => db.getAllExtractedResult(keys, jsonPaths);
}

class _IsolateEncodableLoadEverything extends _IsolateEncodable {
  const _IsolateEncodableLoadEverything();

  @override
  List<Map<String, dynamic>> execute(DBWrapperSync db) => db.loadEverythingResult();
}

class _IsolateEncodableLoadEverythingKeyed extends _IsolateEncodable {
  const _IsolateEncodableLoadEverythingKeyed();

  @override
  Map<String, Map<String, dynamic>> execute(DBWrapperSync db) => db.loadEverythingKeyedResult();
}

class _IsolateEncodableLoadAllKeys extends _IsolateEncodable {
  const _IsolateEncodableLoadAllKeys();

  @override
  List<String> execute(DBWrapperSync db) => db.loadAllKeysResult();
}
