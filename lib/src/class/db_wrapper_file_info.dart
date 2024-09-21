// ignore_for_file: public_member_api_docs, sort_constructors_first
part of '../../namico_db_wrapper.dart';

/// Holds the file information for the db.
class DbWrapperFileInfo {
  final File file;
  final String directory;
  final String dbName;
  final String filenameActual;
  final String extension;

  const DbWrapperFileInfo._({
    required this.file,
    required this.directory,
    required this.dbName,
    required this.filenameActual,
    required this.extension,
  });

  factory DbWrapperFileInfo({required String directory, required String dbName, String? encryptionKey}) {
    if (!directory.endsWith(Platform.pathSeparator)) directory += Platform.pathSeparator;
    final extension = encryptionKey != null ? '' : '.db';
    final actualFilename = '$dbName$extension';
    final path = "$directory$actualFilename";
    final file = File(path);

    return DbWrapperFileInfo._(
      directory: directory,
      dbName: dbName,
      filenameActual: actualFilename,
      extension: extension,
      file: file,
    );
  }

  @override
  String toString() {
    return 'DbWrapperFileInfo(file: $file, directory: $directory, dbName: $dbName, filenameActual: $filenameActual, extension: $extension)';
  }
}
