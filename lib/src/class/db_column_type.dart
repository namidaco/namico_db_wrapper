part of '../../namico_db_wrapper.dart';

class DBColumnType {
  /// Column type.
  final DBColumnTypeEnum type;

  /// Column name.
  final String name;

  /// Wether this column is nullable or not. please note that insertions like in [DBWrapper.put],
  /// will require the field if the column didn't exist before && [defaultValue] is null, otherwise it will throw an error.
  ///
  /// When adding a new column dynamically & [nullable] is false, [defaultValue] should be provided.
  final bool nullable;

  /// The default value for the column, required when
  /// [nullable] == false && (the column didn't exist before || inserting object without this column).
  final dynamic defaultValue;

  const DBColumnType({
    required this.type,
    required this.name,
    required this.nullable,
    this.defaultValue,
  });
}
