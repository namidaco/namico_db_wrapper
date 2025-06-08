// ignore_for_file: public_member_api_docs, sort_constructors_first
part of '../../namico_db_wrapper.dart';

class DBConfig {
  static const Duration defaultDisposeTimerDuration = Duration(minutes: 5);

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

  const DBConfig({
    this.encryptionKey,
    this.customTypes,
    this.createIfNotExist = false,
    this.autoDisposeTimerDuration = DBConfig.defaultDisposeTimerDuration,
  });

  const DBConfig.required({
    required this.encryptionKey,
    required this.customTypes,
    required this.createIfNotExist,
    required this.autoDisposeTimerDuration,
  });

  DBConfig copyWith({
    String? encryptionKey,
    List<DBColumnType>? customTypes,
    bool? createIfNotExist,
    Duration? autoDisposeTimerDuration,
  }) =>
      DBConfig(
        encryptionKey: encryptionKey ?? this.encryptionKey,
        customTypes: customTypes ?? this.customTypes,
        createIfNotExist: createIfNotExist ?? this.createIfNotExist,
        autoDisposeTimerDuration: autoDisposeTimerDuration ?? this.autoDisposeTimerDuration,
      );
}
