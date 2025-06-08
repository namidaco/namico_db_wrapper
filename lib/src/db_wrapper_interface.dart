part of '../namico_db_wrapper.dart';

abstract mixin class DBWrapperInterfaceAsync<D> implements DBWrapperInterfaceSync {
  @override
  Future<DBWrapperInterfaceAsync> reOpen();

  @override
  Future<void> claimFreeSpace();

  @override
  Future<List<Map<String, dynamic>>> loadEverythingResult();

  @override
  Future<Map<String, Map<String, dynamic>>> loadEverythingKeyedResult();

  @override
  Future<List<String>> loadAllKeysResult();

  @override
  Future<Map<String, dynamic>?> get(String key);

  @override
  Future<List<Map<String, dynamic>>> getAll(List<String> keys);

  @override
  Future<void> put(String key, Map<String, dynamic>? object);

  /// same as [put] but for multiple values.
  Future<void> putAll<E>(List<E> items, CacheWriteItemToEntryCallback<E> itemToEntry);

  /// same as [putAll] except that [putAll] is better with lists.
  Future<void> putAllIterable<E>(Iterable<E> items, CacheWriteItemToEntryCallback<E> itemToEntry);

  @override
  Future<void> delete(String key);

  @override
  Future<void> deleteEverything({required bool claimFreeSpace});

  @override
  Future<void> close();
}

abstract mixin class DBWrapperInterfaceSync {
  /// Wether the db is currently open or not.
  bool get isOpen;

  FutureOr<DBWrapperInterfaceSync> reOpen();

  /// Claim free space after duplicate inserts or deletions. this can be an expensive operation
  FutureOr<void> claimFreeSpace();

  /// Load all rows inside the db. if [DBConfig.customTypes] are provided then the key will exist in the map provided, otherwise see [loadEverythingKeyed].
  FutureOr<List<Map<String, dynamic>>> loadEverythingResult();

  /// Load all rows inside the db with their key.
  FutureOr<Map<String, Map<String, dynamic>>> loadEverythingKeyedResult();

  /// Load all keys inside the db.
  FutureOr<List<String>> loadAllKeysResult();

  /// Wether the db contains [key] or not. note that null values are allowed so the key may exist with a null value.
  /// In that case you might need to check the actual value by [get].
  FutureOr<bool> containsKey(String key);

  /// get a value of a key. this can return null if key doesn't exist or value is null.
  /// use [containsKey] if you want to check the key itself
  FutureOr<Map<String, dynamic>?> get(String key);

  FutureOr<List<Map<String, dynamic>>> getAll(List<String> keys);

  /// puts a value [object] to a [key] in the db. if the key already exists then it's overriden.
  /// if [DBConfig.customTypes] are provided then the keys of [object] should be the same as the column names of [DBConfig.customTypes].
  FutureOr<void> put(String key, Map<String, dynamic>? object);

  /// delete a single row inside the db.
  FutureOr<void> delete(String key);

  /// delete multiple rows inside the db.
  FutureOr<void> deleteBulk(List<String> keys);

  /// delete all rows inside the db.
  FutureOr<void> deleteEverything({required bool claimFreeSpace});

  /// close the db and free allocated resources.
  FutureOr<void> close();
}
