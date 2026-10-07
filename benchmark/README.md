# namico_db_wrapper benchmark

Raw sqlite3 key-value layouts, value encodings and pragmas, plus hive_ce and isolate round trips as reference.
Results of the last run are in [results.md](results.md).

Run AOT, JIT numbers are not representative:

```sh
cd benchmark
dart pub get
dart build cli -t bin/bench.dart -o build/bench
build/bench/bundle/bin/bench.exe                  # all phases
build/bench/bundle/bin/bench.exe schema codec     # json, schema, pragma, codec, extract, bind

dart build cli -t bin/hive_bench.dart -o build/hive && build/hive/bundle/bin/hive_bench.exe
dart build cli -t bin/isolate_bench.dart -o build/isolate && build/isolate/bundle/bin/isolate_bench.exe
```

`dart build cli` is needed instead of `dart compile exe` since sqlite3 ships its native library through build hooks.
