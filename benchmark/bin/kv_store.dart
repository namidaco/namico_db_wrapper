// by claude
// ignore_for_file: experimental_member_use

part of 'bench.dart';

class _KVStore {
  static const _kTable = 'kv';
  static const _kChunkSize = 999;

  final Database db;
  final _Schema schema;
  final _ValueCodec codec;
  final String path;
  final String _keyColumn;
  final PreparedStatement _upsertSt;
  final PreparedStatement _getSt;
  final PreparedStatement _existsSt;

  _KVStore._(this.db, this.schema, this.codec, this.path, this._upsertSt, this._getSt, this._existsSt) : _keyColumn = schema == _Schema.hashRowid ? 'id' : 'key';

  factory _KVStore.create(String path, _Schema schema, _ValueCodec codec, _Pragmas pragmas) {
    for (final suffix in ['', '-wal', '-shm']) {
      final file = File('$path$suffix');
      if (file.existsSync()) file.deleteSync();
    }
    final db = sqlite3.open(path, mutex: pragmas.mutex);
    pragmas.apply(db);
    final createSql = _buildCreateSql(schema, codec.sqlType);
    db.execute(createSql);
    final upsertSql = _buildUpsertSql(schema, codec);
    final getSql = _buildGetSql(schema);
    final existsSql = _buildExistsSql(schema);
    final upsertSt = db.prepare(upsertSql, persistent: true);
    final getSt = db.prepare(getSql, persistent: true);
    final existsSt = db.prepare(existsSql, persistent: true);
    return _KVStore._(db, schema, codec, path, upsertSt, getSt, existsSt);
  }

  static String _buildCreateSql(_Schema schema, String valueType) => switch (schema) {
        _Schema.current => 'CREATE TABLE $_kTable (key TEXT NOT NULL UNIQUE, value $valueType, PRIMARY KEY (key))',
        _Schema.withoutRowid => 'CREATE TABLE $_kTable (key TEXT NOT NULL PRIMARY KEY, value $valueType) WITHOUT ROWID',
        _Schema.hashRowid => 'CREATE TABLE $_kTable (id INTEGER PRIMARY KEY, key TEXT NOT NULL, value $valueType)',
      };

  static String _buildUpsertSql(_Schema schema, _ValueCodec codec) => schema == _Schema.hashRowid
      ? 'INSERT INTO $_kTable (id, key, value) VALUES (?, ?, ${codec.placeholder}) ON CONFLICT (id) DO UPDATE SET key=EXCLUDED.key, value=EXCLUDED.value'
      : 'INSERT INTO $_kTable (key, value) VALUES (?, ${codec.placeholder}) ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value';

  static String _buildGetSql(_Schema schema) =>
      schema == _Schema.hashRowid ? 'SELECT value, key FROM $_kTable WHERE id = ?' : 'SELECT value FROM $_kTable WHERE key = ?';

  static String _buildExistsSql(_Schema schema) =>
      schema == _Schema.hashRowid ? 'SELECT key FROM $_kTable WHERE id = ?' : 'SELECT 1 FROM $_kTable WHERE key = ?';

  String _buildInSql(String prefix, int count) {
    final sb = StringBuffer('$prefix WHERE $_keyColumn IN (?');
    for (int i = 1; i < count; i++) {
      sb.write(',?');
    }
    sb.write(')');
    return sb.toString();
  }

  void _bindKey(RawPreparedStatement raw, int index, String key) {
    if (schema == _Schema.hashRowid) {
      final hash = _fnv1a64(key);
      raw.bindInt64(index, hash);
    } else {
      raw.bindText(index, key);
    }
  }

  void transaction(void Function() fn) {
    db.execute('BEGIN IMMEDIATE');
    fn();
    db.execute('COMMIT');
  }

  void put(String key, Map<String, dynamic> value) {
    final raw = _upsertSt.raw;
    _upsertSt.reset();
    if (schema == _Schema.hashRowid) {
      final hash = _fnv1a64(key);
      raw.bindInt64(1, hash);
      raw.bindText(2, key);
      codec.bind(raw, 3, value);
    } else {
      raw.bindText(1, key);
      codec.bind(raw, 2, value);
    }
    raw.step();
  }

  bool _stepGet(String key) {
    final raw = _getSt.raw;
    _getSt.reset();
    _bindKey(raw, 1, key);
    if (!raw.step()) return false;
    return schema != _Schema.hashRowid || raw.columnText(1) == key;
  }

  Map<String, dynamic>? get(String key) {
    try {
      final didFind = _stepGet(key);
      if (!didFind) return null;
      return codec.read(_getSt.raw, 0);
    } finally {
      _getSt.reset();
    }
  }

  Object? getNoDecode(String key) {
    try {
      final didFind = _stepGet(key);
      if (!didFind) return null;
      return codec.readNoDecode(_getSt.raw, 0);
    } finally {
      _getSt.reset();
    }
  }

  bool containsKey(String key) {
    final raw = _existsSt.raw;
    _existsSt.reset();
    _bindKey(raw, 1, key);
    try {
      if (!raw.step()) return false;
      return schema != _Schema.hashRowid || raw.columnText(0) == key;
    } finally {
      _existsSt.reset();
    }
  }

  int getAll(List<String> keys) {
    final selectPrefix = schema == _Schema.hashRowid ? 'SELECT value, key FROM $_kTable' : 'SELECT value FROM $_kTable';
    int foundCount = 0;
    for (int start = 0; start < keys.length; start += _kChunkSize) {
      final count = min(_kChunkSize, keys.length - start);
      final sql = _buildInSql(selectPrefix, count);
      final st = db.prepare(sql);
      final raw = st.raw;
      for (int i = 0; i < count; i++) {
        _bindKey(raw, i + 1, keys[start + i]);
      }
      while (raw.step()) {
        codec.read(raw, 0);
        foundCount++;
      }
      st.close();
    }
    return foundCount;
  }

  int loadEverythingKeyed() {
    final st = db.prepare('SELECT value, key FROM $_kTable');
    final raw = st.raw;
    final map = <String, Map<String, dynamic>>{};
    while (raw.step()) {
      final key = raw.columnText(1);
      map[key] = codec.read(raw, 0);
    }
    st.close();
    return map.length;
  }

  int loadAllKeys() {
    final st = db.prepare('SELECT key FROM $_kTable');
    final raw = st.raw;
    final keys = <String>[];
    while (raw.step()) {
      keys.add(raw.columnText(0));
    }
    st.close();
    return keys.length;
  }

  void deleteBulk(List<String> keys) {
    transaction(() {
      for (int start = 0; start < keys.length; start += _kChunkSize) {
        final count = min(_kChunkSize, keys.length - start);
        final sql = _buildInSql('DELETE FROM $_kTable', count);
        final st = db.prepare(sql);
        final raw = st.raw;
        for (int i = 0; i < count; i++) {
          _bindKey(raw, i + 1, keys[start + i]);
        }
        raw.step();
        st.close();
      }
    });
  }

  int checkpointAndGetSize() {
    db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    return File(path).lengthSync();
  }

  void close() {
    _upsertSt.close();
    _getSt.close();
    _existsSt.close();
    db.close();
  }
}

int _fnv1a64(String text) {
  int hash = 0xcbf29ce484222325;
  for (int i = 0; i < text.length; i++) {
    hash ^= text.codeUnitAt(i);
    hash *= 0x100000001b3;
  }
  return hash;
}

abstract class _ValueCodec {
  const _ValueCodec();

  String get name;
  String get sqlType;
  String get placeholder => '?';

  void bind(RawPreparedStatement st, int index, Map<String, dynamic> value);
  Map<String, dynamic> read(RawPreparedStatement st, int index);
  Object readNoDecode(RawPreparedStatement st, int index);
}

class _TextJsonCodec extends _ValueCodec {
  const _TextJsonCodec();

  @override
  String get name => 'text json';

  @override
  String get sqlType => 'TEXT';

  @override
  void bind(RawPreparedStatement st, int index, Map<String, dynamic> value) {
    final text = jsonEncode(value);
    st.bindText(index, text);
  }

  @override
  Map<String, dynamic> read(RawPreparedStatement st, int index) {
    final text = st.columnText(index);
    return jsonDecode(text) as Map<String, dynamic>;
  }

  @override
  Object readNoDecode(RawPreparedStatement st, int index) => st.columnText(index);
}

class _TextReadBytesCodec extends _TextJsonCodec {
  const _TextReadBytesCodec();

  @override
  String get name => 'text, read bytes+fused';

  @override
  Map<String, dynamic> read(RawPreparedStatement st, int index) {
    final bytes = st.columnBlob(index);
    return utf8JsonDecode(bytes) as Map<String, dynamic>;
  }

  @override
  Object readNoDecode(RawPreparedStatement st, int index) => st.columnBlob(index);
}

class _TextBytesCodec extends _TextReadBytesCodec {
  const _TextBytesCodec();

  @override
  String get name => 'text, utf8 bytes both ways';

  @override
  String get placeholder => 'CAST(? AS TEXT)';

  @override
  void bind(RawPreparedStatement st, int index, Map<String, dynamic> value) {
    final bytes = utf8JsonEncode(value);
    st.bindBlob(index, bytes);
  }
}

class _BlobJsonCodec extends _ValueCodec {
  const _BlobJsonCodec();

  @override
  String get name => 'blob utf8 json';

  @override
  String get sqlType => 'BLOB';

  @override
  void bind(RawPreparedStatement st, int index, Map<String, dynamic> value) {
    final bytes = utf8JsonEncode(value);
    st.bindBlob(index, bytes);
  }

  @override
  Map<String, dynamic> read(RawPreparedStatement st, int index) {
    final bytes = st.columnBlob(index);
    return utf8JsonDecode(bytes) as Map<String, dynamic>;
  }

  @override
  Object readNoDecode(RawPreparedStatement st, int index) => st.columnBlob(index);
}

class _BlobJsonbCodec extends _ValueCodec {
  const _BlobJsonbCodec();

  @override
  String get name => 'blob jsonb';

  @override
  String get sqlType => 'BLOB';

  @override
  void bind(RawPreparedStatement st, int index, Map<String, dynamic> value) {
    final bytes = jsonb.encode(value);
    st.bindBlob(index, bytes);
  }

  @override
  Map<String, dynamic> read(RawPreparedStatement st, int index) {
    final bytes = st.columnBlob(index);
    return jsonb.decode(bytes) as Map<String, dynamic>;
  }

  @override
  Object readNoDecode(RawPreparedStatement st, int index) => st.columnBlob(index);
}

enum _Schema {
  current,
  withoutRowid,
  hashRowid,
  ;

  String toText() => switch (this) {
        _Schema.current => 'rowid + text key index (current)',
        _Schema.withoutRowid => 'WITHOUT ROWID text pk',
        _Schema.hashRowid => 'hash64 rowid, no index',
      };
}

class _Pragmas {
  final int pageSize;
  final int? cacheSizeKiB;
  final int? mmapSize;
  final bool mutex;

  const _Pragmas({
    this.pageSize = 4096,
    this.cacheSizeKiB,
    this.mmapSize,
    this.mutex = true,
  });

  String toText() {
    final cacheSizeKiB = this.cacheSizeKiB;
    final mmapSize = this.mmapSize;
    final sb = StringBuffer('page=${pageSize ~/ 1024}K');
    if (cacheSizeKiB != null) sb.write(' cache=${cacheSizeKiB ~/ 1024}M');
    if (mmapSize != null) sb.write(' mmap=${mmapSize >> 20}M');
    if (!mutex) sb.write(' nomutex');
    return sb.toString();
  }

  void apply(Database db) {
    final cacheSizeKiB = this.cacheSizeKiB;
    final mmapSize = this.mmapSize;
    db.execute('PRAGMA page_size=$pageSize;');
    db.execute('PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; PRAGMA temp_store=MEMORY; PRAGMA busy_timeout=15000;');
    if (cacheSizeKiB != null) db.execute('PRAGMA cache_size=-$cacheSizeKiB;');
    if (mmapSize != null) db.execute('PRAGMA mmap_size=$mmapSize;');
  }
}
