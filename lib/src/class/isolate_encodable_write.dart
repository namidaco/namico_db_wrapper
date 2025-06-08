part of '../../namico_db_wrapper.dart';

class _IsolateEncodableWriteList extends _IsolateEncodable {
  final DBWriteList writeList;
  const _IsolateEncodableWriteList(this.writeList);

  @override
  void execute(DBWrapperSync db) => db.putAll(writeList);
}

class _IsolateEncodableClaimFreeSpace extends _IsolateEncodable {
  const _IsolateEncodableClaimFreeSpace();

  @override
  void execute(DBWrapperSync db) => db.claimFreeSpace();
}

class _IsolateEncodableDelete extends _IsolateEncodable {
  final String key;
  const _IsolateEncodableDelete(this.key);

  @override
  void execute(DBWrapperSync db) => db.delete(key);
}

class _IsolateEncodableDeleteBulk extends _IsolateEncodable {
  final List<String> keys;
  const _IsolateEncodableDeleteBulk(this.keys);

  @override
  void execute(DBWrapperSync db) => db.deleteBulk(keys);
}

class _IsolateEncodableDeleteEverything extends _IsolateEncodable {
  const _IsolateEncodableDeleteEverything();

  @override
  void execute(DBWrapperSync db) => db.deleteEverything(claimFreeSpace: false);
}

class _IsolateEncodableDeleteEverythingAndClaimSpace extends _IsolateEncodable {
  const _IsolateEncodableDeleteEverythingAndClaimSpace();

  @override
  void execute(DBWrapperSync db) => db.deleteEverything(claimFreeSpace: true);
}
