// ignore_for_file: public_member_api_docs, sort_constructors_first
part of '../../namico_db_wrapper.dart';

class DBConfig {
  static const Duration defaultDisposeTimerDuration = Duration(minutes: 5);
  static const int defaultCacheSizeInMB = 16;
  static const int defaultMmapSizeInMB = 256;

  /// Encryption key for the whole database.
  final String? encryptionKey;

  /// Defines the columns for the database.
  ///
  /// Columns that are added later after the table is already created, will be added inside the db by executing `ALTER TABLE table_name ADD COLUMN column_name`,
  /// this can be quite an expensive operation depending on how large the db is.
  ///
  /// Columns that are removed will not be deleted from the db.
  final List<DBColumnType>? customTypes;

  /// Create the db file if it doesn't exist.
  final bool createIfNotExist;

  /// Automatically dispose the database if was idle for more than [autoDisposeTimerDuration].
  ///
  /// Defaults to [DBConfig.defaultDisposeTimerDuration].
  final Duration? autoDisposeTimerDuration;

  /// Max page cache size (`PRAGMA cache_size`), only allocated as pages get used. null keeps sqlite default (2MB).
  ///
  /// Defaults to [DBConfig.defaultCacheSizeInMB].
  final int? cacheSizeInMB;

  /// Max memory mapped size of the db file (`PRAGMA mmap_size`), maps only as much as the file size. null disables it.
  /// Speeds up reads a lot by skipping a read syscall per page, ignored for encrypted dbs.
  ///
  /// Defaults to [DBConfig.defaultMmapSizeInMB].
  final int? mmapSizeInMB;

  /// Holds single [DBWrapperAsync.put] & [DBWrapperAsync.delete] calls for this long, then sends them as one transaction. null sends each right away.
  ///
  /// Reads & bulk writes send the held writes first, so they always see them. Held writes are lost if the app is killed before they are sent.
  /// Ignored by [DBWrapperSync] & [DBWrapper.openSyncAsync].
  final Duration? batchWritesDelay;

  const DBConfig({
    this.encryptionKey,
    this.customTypes,
    this.createIfNotExist = false,
    this.autoDisposeTimerDuration = DBConfig.defaultDisposeTimerDuration,
    this.cacheSizeInMB = DBConfig.defaultCacheSizeInMB,
    this.mmapSizeInMB = DBConfig.defaultMmapSizeInMB,
    this.batchWritesDelay,
  });

  const DBConfig.required({
    required this.encryptionKey,
    required this.customTypes,
    required this.createIfNotExist,
    required this.autoDisposeTimerDuration,
    required this.cacheSizeInMB,
    required this.mmapSizeInMB,
    required this.batchWritesDelay,
  });

  DBConfig copyWith({
    String? encryptionKey,
    List<DBColumnType>? customTypes,
    bool? createIfNotExist,
    Duration? autoDisposeTimerDuration,
    int? cacheSizeInMB,
    int? mmapSizeInMB,
    Duration? batchWritesDelay,
  }) =>
      DBConfig(
        encryptionKey: encryptionKey ?? this.encryptionKey,
        customTypes: customTypes ?? this.customTypes,
        createIfNotExist: createIfNotExist ?? this.createIfNotExist,
        autoDisposeTimerDuration: autoDisposeTimerDuration ?? this.autoDisposeTimerDuration,
        cacheSizeInMB: cacheSizeInMB ?? this.cacheSizeInMB,
        mmapSizeInMB: mmapSizeInMB ?? this.mmapSizeInMB,
        batchWritesDelay: batchWritesDelay ?? this.batchWritesDelay,
      );

  @override
  bool operator ==(covariant DBConfig other) {
    if (identical(this, other)) return true;

    return other.encryptionKey == encryptionKey &&
        listEquals(other.customTypes, customTypes) &&
        other.createIfNotExist == createIfNotExist &&
        other.autoDisposeTimerDuration == autoDisposeTimerDuration &&
        other.cacheSizeInMB == cacheSizeInMB &&
        other.mmapSizeInMB == mmapSizeInMB &&
        other.batchWritesDelay == batchWritesDelay;
  }

  @override
  int get hashCode {
    final customTypes = this.customTypes;
    final customTypesHash = customTypes == null ? null : Object.hashAll(customTypes);
    return Object.hash(encryptionKey, customTypesHash, createIfNotExist, autoDisposeTimerDuration, cacheSizeInMB, mmapSizeInMB, batchWritesDelay);
  }

  @override
  String toString() {
    return 'DBConfig(encryptionKey: $encryptionKey, customTypes: $customTypes, createIfNotExist: $createIfNotExist, autoDisposeTimerDuration: $autoDisposeTimerDuration, cacheSizeInMB: $cacheSizeInMB, mmapSizeInMB: $mmapSizeInMB, batchWritesDelay: $batchWritesDelay)';
  }
}
