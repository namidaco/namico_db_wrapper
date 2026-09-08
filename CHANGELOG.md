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
