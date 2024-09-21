part of '../../namico_db_wrapper.dart';

class DBKeyedResults {
  final String key;
  final Map<String, dynamic>? map;

  const DBKeyedResults({
    required this.key,
    required this.map,
  });
}
