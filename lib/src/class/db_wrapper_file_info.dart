// ignore_for_file: public_member_api_docs, sort_constructors_first
part of '../../namico_db_wrapper.dart';

/// Holds the file information for the db.
class DbWrapperFileInfo {
  final File file;
  final String directory;
  final String dbName;
  final String filenameActual;
  final String extension;
  final String dbTableName;
  final String dbOpenUriFinal;

  const DbWrapperFileInfo._({
    required this.file,
    required this.directory,
    required this.dbName,
    required this.filenameActual,
    required this.extension,
    required this.dbOpenUriFinal,
  }) : dbTableName = '`$dbName`';

  factory DbWrapperFileInfo({required String directory, required String dbName, String? encryptionKey}) {
    directory = _normalizeDirectory(directory);
    final extension = encryptionKey != null ? '' : '.db';
    final actualFilename = '$dbName$extension';
    final dbFile = File("$directory$actualFilename");

    return DbWrapperFileInfo._(
      directory: directory,
      dbName: dbName,
      filenameActual: actualFilename,
      extension: extension,
      file: dbFile,
      dbOpenUriFinal: _buildOpenUri(dbFile),
    );
  }

  factory DbWrapperFileInfo.fromFile({required File dbFile, String? encryptionKey}) {
    final path = dbFile.path;
    return DbWrapperFileInfo._(
      directory: _normalizeDirectory(p.dirname(path)),
      dbName: p.basenameWithoutExtension(path),
      filenameActual: p.basename(path),
      extension: p.extension(path),
      file: dbFile,
      dbOpenUriFinal: _buildOpenUri(dbFile),
    );
  }

  static String _normalizeDirectory(String directory) {
    return directory.endsWith(Platform.pathSeparator) ? directory : '$directory${Platform.pathSeparator}';
  }

  static String _buildOpenUri(File file) => Uri.file(file.path).toString();

  @override
  String toString() {
    return 'DbWrapperFileInfo(file: $file, directory: $directory, dbName: $dbName, filenameActual: $filenameActual, extension: $extension, dbTableName: $dbTableName, dbOpenUriFinal: $dbOpenUriFinal)';
  }

  @override
  bool operator ==(covariant DbWrapperFileInfo other) {
    if (identical(this, other)) return true;
    return other.file.path == file.path && other.dbTableName == dbTableName && other.dbOpenUriFinal == dbOpenUriFinal;
  }

  @override
  int get hashCode => Object.hash(file.path, dbTableName, dbOpenUriFinal);
}
