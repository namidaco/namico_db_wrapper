## Simple and Safe dart key-based wrapper for sqlite3 that facilitates readings/insertions/deletions/etc.


## Basic Usage:

- opening database
```dart
// initialize sql once in your `main()` function.
NamicoDBWrapper.initialize();

// `DBWrapper.open()` accepts `directory path & db name`.
final db = DBWrapper.open(
  directoryPath, dbName,
  createIfNotExist: true, // create the db file if it doesnt exist. default: `false`
  encryptionKey: 'my_key', // optional encryption key. default: `null`
);

// Alternatively, `DBWrapper.openFromInfo()` accepts `DbWrapperFileInfo`
// `DbWrapperFileInfo` allows accessing the final db file that will be created.
final db = DBWrapper.openFromInfo(
  fileInfo: DbWrapperFileInfo(
    dbFileName: dbName,
    directory: directoryPath,
  ),
);

```

- specifying custom columns
  
by default, the db saves objects using unique string keys. if custom columns are not provided, then the object is stored as a json-encoded string in the `value` column
```dart
// when opening a db again and this list is changed since the previous time, the new columns are 
// dynamically added using `ALTER TABLE`, this can be an expensive operation so be careful editing this.
// removed columns are not deleted from the db.
final customTypes = [
  DBColumnType(
    type: DBColumnTypeEnum.string,
    name: 'username',
    nullable: false,
  ),
  DBColumnType(
    type: DBColumnTypeEnum.bool,
    name: 'is_cool',
    nullable: true,
  ),
  DBColumnType(
    type: DBColumnTypeEnum.bool,
    name: 'is_cool2',
    nullable: false, // when the field is non-nullable, either a default value must be provided or any next insertions should contain this field. otherwise it will throw an error
    defaultValue: 0,
  ),
  // -- this will throw an error when inserting without this field, since its non-nullable & no default value provided.
  // DBColumnType(
  //   type: DBColumnTypeEnum.bool,
  //   name: 'is_cool3',
  //   nullable: false,
  //   defaultValue: null,
  // ),
];

final customdb = DBWrapper.open(
  directoryPath,
  dbName,
  customTypes: customTypes,
);
```

## read/write
```dart
final unique_key = 'unique_key';
final object = {'name': 'cool', 'count': 2};
db.put(unique_key, object);
final result = db.get(unique_key);
print(result); // {'name': 'cool', 'count': 2}
```

## read/write (Async)
asynchronous methods run on a separate *single* isolate, executing multiple async functions simultaneously will be safe, since operations would still be blocked but on another isolate.

```dart
final unique_key = 'unique_key';
final object = {'name': 'cool', 'count': 2};
await db.putAsync(unique_key, object);
final result = await db.getAsync(unique_key);
print(result); // {'name': 'cool', 'count': 2}
```

## delete
```dart
final unique_key = 'unique_key';
db.delete(unique_key, object);
final result = db.get(unique_key);
print(result); // null
```

## extras
```dart

// load everything (all rows)
db.loadEverything(
  (Map<String, dynamic> value) {
    print(value);
  },
);

// load everything keyed (all rows)
db.loadEverythingKeyed(
  (String key, Map<String, dynamic> value) {
    print('key: $key, value: $value');
  },
);

// check if key exist in the db
final bool keyExists = db.containsKey('unique_key');

// delete everything (all rows)
db.deleteEverything();
```


## close
see [DBWrapper.close()](./lib/src/namico_db_wrapper_base.dart#L103) & [_DBIsolateManager._prepareResourcesAndListen()](./lib/src/namico_db_wrapper_base.dart#L380) to know what resources are allocated
```dart
final db = DBWrapper.open(dir, 'test_db');
db.put(unique_key, object);
db.close(); // close db and free allocated resources.
```

## managing multiple open databases
```dart
final databasesDirectory = 'test_dir';
final manager = DBWrapperMain.init(databasesDirectory);
final db = manager.getDB('my_db'); // opens a new db
final db2 = manager.getDB('my_db'); // retrieve the opened db
manager.close('my_db'); // close db and free resources
manager.closeAll(); // close all databases opened in the specified directory
```


# LICENSE
This project is licenced under [BSD 3-Clause License](LICENSE)