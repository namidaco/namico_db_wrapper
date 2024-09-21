// ignore_for_file: public_member_api_docs, sort_constructors_first
part of '../../namico_db_wrapper.dart';

/// Holds the file information for the db.
class DbWrapperFileInfo {
  final File file;
  final String directory;
  final String filenameOriginal;
  final String filenameActual;
  final String extension;

  const DbWrapperFileInfo({
    required this.file,
    required this.directory,
    required this.filenameOriginal,
    required this.filenameActual,
    required this.extension,
  });

  factory DbWrapperFileInfo.fromInfo({required String directory, required String dbFileName, String? encryptionKey}) {
    if (!directory.endsWith(Platform.pathSeparator)) directory += Platform.pathSeparator;
    final extension = encryptionKey != null ? '' : '.db';
    final actualFilename = '$dbFileName$extension';
    final path = "$directory$actualFilename";
    final file = File(path);

    return DbWrapperFileInfo(
      directory: directory,
      filenameOriginal: dbFileName,
      filenameActual: actualFilename,
      extension: extension,
      file: file,
    );
  }

  @override
  String toString() {
    return 'DbWrapperFileInfo(file: $file, directory: $directory, filenameOriginal: $filenameOriginal, filenameActual: $filenameActual, extension: $extension)';
  }
}
