## 5.4.0

### Performance

- json values are read as raw utf8 bytes & decoded with a fused utf8+json decoder, and written as utf8 bytes cast to TEXT. the stored format is unchanged.
- bigger page cache & memory mapped reads by default, see `DBConfig.cacheSizeInMB` & `DBConfig.mmapSizeInMB` (mmap is skipped for encrypted dbs).
- auto dispose no longer recreates a timer on every call.
- writes bind parameters directly instead of going through `execute()`.

| Operation (AOT, default config) | 100k small values, 11 chars keys | 100k small values, path keys | 4k x 16KB values |
|---|---|---|---|
| `get` all keys | 1408 -> 386ms | 1719 -> 452ms | 455 -> 179ms |
| `containsKey` all keys | 740 -> 247ms | 1143 -> 288ms | 23 -> 13ms |
| `getAll` | 846 -> 266ms | 1020 -> 343ms | 522 -> 301ms |
| `putAll` (insert) | 512 -> 389ms | 1605 -> 537ms | 893 -> 874ms |
| `putAll` (update) | 431 -> 330ms | 721 -> 335ms | 461 -> 477ms |
| `loadEverythingKeyed` | 206 -> 188ms | 234 -> 217ms | 793 -> 334ms |
| async `get` x2000 | 70 -> 41ms | 94 -> 49ms | 336 -> 158ms |
| async `getAll` | 908 -> 344ms | 1252 -> 481ms | 699 -> 467ms |

### Features

- `getExtracted` & `getAllExtractedResult` (+ sync `getAllExtracted`) read only some json fields, extracted by sqlite. ~3x faster than `get` for large values.

### Fixes

- `loadEverythingExtracted` paths are bound as parameters instead of being inlined in sql.

### Breaking

- `DBCommandsBase.objectToWriteParameters` is replaced by `bindWriteParameters`, `loadEverythingExtractedCommand` takes the paths count.
- `DBConfig.required` requires `cacheSizeInMB` & `mmapSizeInMB`.

## 5.1.0

### Performance

- bulk writes & deletes run in a single transaction, exposed as `DBWrapperSync.transaction()`.
- dropped shared-cache mode, which serialized connections & caused lock errors.
- reads use raw prepared statements, skipping per-call result set overhead.
- long-lived statements are persistent & cached, including custom column write statements.
- removed redundant work in auto-dispose timers, write list building & isolate messaging.

| Operation (sync, 20k rows) | Before | After |
|---|---|---|
| `putAll` | 1939ms | ~90ms |
| `put` x10k | 1577ms | ~250ms |
| `containsKey` x20k | 68ms | ~47ms |
| `get` x20k | 105ms | ~90ms |
| `loadAllKeys` x5 | 36ms | ~25ms |
| `getAll` x5 | 184ms | ~150ms |

### Fixes

- custom columns: wrong column order & parameter count mismatch when writing, invalid sql for null/empty objects, broken `DEFAULT` literals.
- instance cache misses due to `DBConfig`/`DbWrapperFileInfo` equality & some open methods bypassing the cache.
- `getAll` & `deleteBulk` exceeding the sqlite parameters limit.
- unnecessary retries on non-lock errors when opening.

### Breaking

- requires `sqlite3: ^3.5.0`.
- `DBCommandsBase` signatures changed.

## 1.0.0

- Initial version.
