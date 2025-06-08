part of '../../namico_db_wrapper.dart';

abstract class _IsolateEncodable {
  const _IsolateEncodable();

  dynamic execute(DBWrapperSync db);

  const factory _IsolateEncodable.containsKey(String key) = _IsolateEncodableContainsKey;
  const factory _IsolateEncodable.readKey(String key) = _IsolateEncodableReadKey;
  const factory _IsolateEncodable.readList(List<String> keys) = _IsolateEncodableReadList;
  const factory _IsolateEncodable.loadEverything() = _IsolateEncodableLoadEverything;
  const factory _IsolateEncodable.loadEverythingKeyed() = _IsolateEncodableLoadEverythingKeyed;
  const factory _IsolateEncodable.loadAllKeys() = _IsolateEncodableLoadAllKeys;

  const factory _IsolateEncodable.writeList(DBWriteList writeList) = _IsolateEncodableWriteList;
  const factory _IsolateEncodable.claimFreeSpace() = _IsolateEncodableClaimFreeSpace;
  const factory _IsolateEncodable.delete(String key) = _IsolateEncodableDelete;
  const factory _IsolateEncodable.deleteBulk(List<String> keys) = _IsolateEncodableDeleteBulk;
  const factory _IsolateEncodable.deleteEverything() = _IsolateEncodableDeleteEverything;
  const factory _IsolateEncodable.deleteEverythingAndClaimSpace() = _IsolateEncodableDeleteEverythingAndClaimSpace;
}
