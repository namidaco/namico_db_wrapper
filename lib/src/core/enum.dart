part of '../../namico_db_wrapper.dart';

enum DBColumnTypeEnum {
  /// Equivalent to `String`.
  string('TEXT'),

  /// Equivalent to `int`.
  int('INT'),

  /// Equivalent to `double`.
  double('REAL'),

  /// Equivalent to `List<int>`.
  intlist('BLOB'),

  /// Equivalent to `bool`. Booleans are saved as 0/1
  bool('BOOL');

  final String dbText;
  const DBColumnTypeEnum(this.dbText);
}
