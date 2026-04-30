part of '../../namico_db_wrapper.dart';

class DatabaseDisposedEarlyException implements Exception {
  final DbWrapperFileInfo fileInfo;
  final DBConfig config;

  const DatabaseDisposedEarlyException({
    required this.fileInfo,
    required this.config,
  });

  @override
  String toString() => 'DB was closed before receiving result.\n${fileInfo.file}\n$config';
}
