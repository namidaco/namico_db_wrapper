part of '../namico_db_wrapper.dart';

abstract interface class DBWrapperInterface {
  void close();

  /// Early prepare the isolate channel responsible for async methods.
  /// This is not really needed unless you want to speed up first time execution.
  Future<void> prepareIsolateChannel();

  /// Claim free space after duplicate inserts or deletions. this can be an expensive operation
  void claimFreeSpace();

  /// Async version of [claimFreeSpace]
  Future<void> claimFreeSpaceAsync();

  /// Load all rows inside the db. if [customTypes] are provided then the key will exist in the map provided, otherwise see [loadEverythingKeyed].
  void loadEverything(void Function(Map<String, dynamic> value) onValue);

  /// Load all rows inside the db with their key.
  void loadEverythingKeyed(void Function(String key, Map<String, dynamic> value) onValue);

  /// Wether the db contains [key] or not. note that null values are allowed so the key may exist with a null value.
  /// In that case you might need to check the actual value by [get].
  bool containsKey(String key);

  /// get a value of a key. this can return null if key doesn't exist or value is null.
  /// use [containsKey] if you want to check the key itself
  Map<String, dynamic>? get(String key);

  List<Map<String, dynamic>> getAll(List<String> keys);

  /// async version of [get].
  Future<Map<String, dynamic>?> getAsync(String key);

  /// async version of [getAll].
  Future<List<Map<String, dynamic>>> getAllAsync(List<String> keys);

  /// puts a value [object] to a [key] in the db. if the key already exists then it's overriden.
  /// if [customTypes] are provided then the keys of [object] should be the same as the column names of [customTypes].
  void put(String key, Map<String, dynamic>? object);

  /// async version of [put].
  Future<void> putAsync(String key, Map<String, dynamic>? object);

  /// same as [put] but for multiple values.
  Future<void> putAllAsync<E>(List<E> items, CacheWriteItemToEntryCallback<E> itemToEntry);

  /// same as [putAllAsync] except that [putAllAsync] is better with lists.
  Future<void> putAllIterableAsync<E>(Iterable<E> items, CacheWriteItemToEntryCallback<E> itemToEntry);

  /// delete a single row inside the db.
  void delete(String key);

  /// async version of [delete].
  Future<void> deleteAsync(String key);

  /// delete all rows inside the db.
  Future<void> deleteEverything();
}
