# Results

AOT, Windows 11, NVMe, 2026-10-07. Write columns vary up to ~2x between runs on this machine, read columns are stable.

sqlite 3.53.4, phases: {json, schema, pragma, codec, extract, bind}
small/ytid (100k): value ~129B json, key ~11 chars e.g. MTIld_cTCqg
small/path (100k): value ~129B json, key ~89 chars e.g. C:\Users\user\Music\Starboy Need\City Faded Faded\07 - Access Punk Punk Heart (16670).m4a
medium/ytid (20k): value ~1272B json, key ~11 chars e.g. jHO8Ei-ywJg
large/ytid (4k): value ~16574B json, key ~11 chars e.g. fj94FPspXH0
times in ms, total for all keys of the dataset. insertSingle = 2000 autocommit puts

### pure dart json cost (µs per value, best of 3, 2000 values)
| dataset | bytes | jsonEncode | jsonEncode+utf8.encode | JsonUtf8Encoder | jsonb.encode | jsonDecode(String) | fused utf8 decode | jsonb.decode | utf8.decode only |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| small/ytid (100k) | 129 | 1.26 | 1.31 | 0.91 | 1.34 | 0.62 | 0.54 | 1.00 | 0.04 |
| small/path (100k) | 129 | 1.05 | 1.34 | 0.95 | 1.28 | 0.65 | 0.54 | 0.97 | 0.04 |
| medium/ytid (20k) | 1272 | 9.72 | 12.17 | 8.65 | 10.37 | 5.10 | 4.12 | 8.05 | 0.19 |
| large/ytid (4k) | 16574 | 65.09 | 98.04 | 86.84 | 65.97 | 66.53 | 27.77 | 40.42 | 29.70 |

### schema: small/ytid (100k), text json, page=4K
| config | insertBulk | insertSingle | updateBulk | get | getNoDecode | contains | getAll | loadAllKeyed | loadKeys | delHalf | sizeMB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| rowid + text key index (current) | 456 | 121 | 362 | 882 | 786 | 260 | 659 | 183 | 17 | 678 | 17.5 |
| WITHOUT ROWID text pk | 1234 | 131 | 657 | 687 | 612 | 572 | 536 | 175 | 34 | 503 | 17.1 |
| hash64 rowid, no index | 1215 | 136 | 610 | 625 | 541 | 514 | 476 | 202 | 42 | 483 | 18.1 |

### schema: small/path (100k), text json, page=4K
| config | insertBulk | insertSingle | updateBulk | get | getNoDecode | contains | getAll | loadAllKeyed | loadKeys | delHalf | sizeMB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| rowid + text key index (current) | 1201 | 172 | 674 | 1175 | 1055 | 624 | 1021 | 216 | 30 | 1107 | 35.0 |
| WITHOUT ROWID text pk | 1962 | 200 | 1098 | 993 | 784 | 777 | 764 | 214 | 45 | 727 | 27.1 |
| hash64 rowid, no index | 2263 | 542 | 671 | 707 | 584 | 553 | 508 | 210 | 46 | 566 | 28.5 |

### schema: medium/ytid (20k), text json, page=4K
| config | insertBulk | insertSingle | updateBulk | get | getNoDecode | contains | getAll | loadAllKeyed | loadKeys | delHalf | sizeMB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| rowid + text key index (current) | 451 | 148 | 309 | 258 | 131 | 40 | 235 | 271 | 3 | 301 | 29.2 |
| WITHOUT ROWID text pk | 2074 | 428 | 1724 | 1188 | 1055 | 1021 | 917 | 341 | 14 | 381 | 98.3 |
| hash64 rowid, no index | 802 | 310 | 433 | 239 | 120 | 108 | 210 | 281 | 31 | 267 | 33.1 |

### schema: large/ytid (4k), text json, page=4K
| config | insertBulk | insertSingle | updateBulk | get | getNoDecode | contains | getAll | loadAllKeyed | loadKeys | delHalf | sizeMB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| rowid + text key index (current) | 841 | 106 | 473 | 410 | 190 | 9 | 402 | 535 | 1 | 30 | 71.0 |
| WITHOUT ROWID text pk | 1398 | 199 | 1332 | 900 | 658 | 488 | 811 | 565 | 3 | 115 | 71.2 |
| hash64 rowid, no index | 881 | 136 | 480 | 412 | 172 | 12 | 415 | 543 | 3 | 32 | 71.2 |

### pragmas: small/ytid (100k), rowid + text key index (current), text json
| config | insertBulk | insertSingle | updateBulk | get | getNoDecode | contains | getAll | loadAllKeyed | loadKeys | delHalf | sizeMB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| page=4K | 458 | 126 | 404 | 981 | 857 | 262 | 679 | 152 | 17 | 760 | 17.5 |
| page=4K cache=16M | 374 | 125 | 288 | 492 | 376 | 221 | 299 | 171 | 16 | 259 | 17.5 |
| page=4K mmap=256M | 442 | 121 | 362 | 399 | 311 | 231 | 235 | 168 | 15 | 670 | 17.5 |
| page=4K cache=16M mmap=256M | 389 | 116 | 291 | 384 | 290 | 225 | 240 | 165 | 15 | 247 | 17.5 |
| page=8K cache=16M mmap=256M | 382 | 139 | 298 | 389 | 303 | 243 | 227 | 170 | 15 | 234 | 17.3 |
| page=4K cache=16M mmap=256M nomutex | 391 | 124 | 325 | 418 | 321 | 246 | 267 | 186 | 12 | 268 | 17.5 |

### pragmas: small/ytid (100k), WITHOUT ROWID text pk, text json
| config | insertBulk | insertSingle | updateBulk | get | getNoDecode | contains | getAll | loadAllKeyed | loadKeys | delHalf | sizeMB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| page=4K | 1312 | 141 | 716 | 771 | 681 | 607 | 554 | 183 | 32 | 573 | 17.1 |
| page=4K cache=16M | 2352 | 1145 | 425 | 460 | 366 | 308 | 306 | 193 | 32 | 291 | 17.1 |
| page=4K mmap=256M | 1912 | 196 | 665 | 377 | 282 | 300 | 224 | 171 | 18 | 1064 | 17.1 |
| page=4K cache=16M mmap=256M | 739 | 376 | 384 | 399 | 277 | 242 | 212 | 164 | 17 | 598 | 17.1 |
| page=8K cache=16M mmap=256M | 753 | 454 | 346 | 357 | 264 | 251 | 209 | 165 | 18 | 179 | 16.7 |
| page=4K cache=16M mmap=256M nomutex | 441 | 131 | 374 | 356 | 261 | 244 | 206 | 164 | 14 | 230 | 17.1 |

### pragmas: small/ytid (100k), hash64 rowid, no index, text json
| config | insertBulk | insertSingle | updateBulk | get | getNoDecode | contains | getAll | loadAllKeyed | loadKeys | delHalf | sizeMB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| page=4K | 1184 | 129 | 604 | 633 | 536 | 526 | 478 | 195 | 31 | 450 | 18.1 |
| page=4K cache=16M | 451 | 136 | 347 | 410 | 324 | 295 | 251 | 198 | 33 | 223 | 18.1 |
| page=4K mmap=256M | 1155 | 140 | 591 | 347 | 256 | 246 | 193 | 171 | 22 | 464 | 18.1 |
| page=4K cache=16M mmap=256M | 472 | 144 | 344 | 337 | 247 | 236 | 190 | 187 | 18 | 233 | 18.1 |
| page=8K cache=16M mmap=256M | 392 | 142 | 337 | 342 | 246 | 233 | 175 | 167 | 16 | 188 | 17.7 |
| page=4K cache=16M mmap=256M nomutex | 446 | 134 | 345 | 326 | 237 | 224 | 174 | 164 | 13 | 218 | 18.1 |

### pragmas: small/path (100k), rowid + text key index (current), text json
| config | insertBulk | insertSingle | updateBulk | get | getNoDecode | contains | getAll | loadAllKeyed | loadKeys | delHalf | sizeMB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| page=4K | 1275 | 169 | 686 | 1121 | 1028 | 586 | 986 | 207 | 29 | 1121 | 35.0 |
| page=4K cache=16M | 651 | 168 | 383 | 904 | 771 | 285 | 731 | 212 | 25 | 856 | 35.0 |
| page=4K mmap=256M | 1229 | 203 | 705 | 464 | 357 | 275 | 317 | 183 | 22 | 989 | 35.0 |
| page=4K cache=16M mmap=256M | 562 | 193 | 403 | 487 | 382 | 281 | 323 | 179 | 18 | 785 | 35.0 |
| page=8K cache=16M mmap=256M | 482 | 164 | 369 | 471 | 371 | 276 | 337 | 183 | 17 | 1669 | 34.7 |
| page=4K cache=16M mmap=256M nomutex | 1275 | 604 | 363 | 462 | 368 | 273 | 335 | 190 | 19 | 1645 | 35.0 |

### pragmas: small/path (100k), WITHOUT ROWID text pk, text json
| config | insertBulk | insertSingle | updateBulk | get | getNoDecode | contains | getAll | loadAllKeyed | loadKeys | delHalf | sizeMB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| page=4K | 1958 | 180 | 866 | 888 | 777 | 773 | 782 | 216 | 42 | 701 | 27.1 |
| page=4K cache=16M | 733 | 193 | 587 | 598 | 498 | 486 | 492 | 210 | 44 | 480 | 27.1 |
| page=4K mmap=256M | 1783 | 196 | 901 | 413 | 314 | 311 | 290 | 194 | 25 | 684 | 27.1 |
| page=4K cache=16M mmap=256M | 782 | 184 | 548 | 403 | 326 | 307 | 282 | 181 | 19 | 463 | 27.1 |
| page=8K cache=16M mmap=256M | 650 | 150 | 589 | 450 | 318 | 330 | 279 | 184 | 24 | 476 | 26.3 |
| page=4K cache=16M mmap=256M nomutex | 745 | 181 | 557 | 426 | 315 | 298 | 287 | 177 | 15 | 474 | 27.1 |

### pragmas: small/path (100k), hash64 rowid, no index, text json
| config | insertBulk | insertSingle | updateBulk | get | getNoDecode | contains | getAll | loadAllKeyed | loadKeys | delHalf | sizeMB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| page=4K | 1458 | 171 | 640 | 673 | 573 | 575 | 507 | 214 | 46 | 569 | 28.5 |
| page=4K cache=16M | 743 | 183 | 563 | 596 | 454 | 436 | 370 | 216 | 49 | 439 | 28.5 |
| page=4K mmap=256M | 1526 | 169 | 637 | 346 | 256 | 249 | 192 | 184 | 20 | 542 | 28.5 |
| page=4K cache=16M mmap=256M | 768 | 173 | 489 | 346 | 258 | 245 | 195 | 182 | 23 | 398 | 28.5 |
| page=8K cache=16M mmap=256M | 628 | 153 | 508 | 349 | 261 | 247 | 195 | 179 | 20 | 360 | 27.2 |
| page=4K cache=16M mmap=256M nomutex | 1618 | 547 | 483 | 339 | 252 | 241 | 197 | 185 | 22 | 1218 | 28.5 |

### pragmas: medium/ytid (20k), rowid + text key index (current), text json
| config | insertBulk | insertSingle | updateBulk | get | getNoDecode | contains | getAll | loadAllKeyed | loadKeys | delHalf | sizeMB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| page=4K | 810 | 479 | 310 | 256 | 130 | 40 | 221 | 250 | 3 | 741 | 29.2 |
| page=4K cache=16M | 1205 | 456 | 309 | 224 | 103 | 42 | 191 | 253 | 3 | 771 | 29.2 |
| page=4K mmap=256M | 437 | 141 | 309 | 180 | 60 | 42 | 143 | 229 | 3 | 262 | 29.2 |
| page=4K cache=16M mmap=256M | 444 | 150 | 311 | 186 | 62 | 40 | 144 | 247 | 3 | 198 | 29.2 |
| page=8K cache=16M mmap=256M | 405 | 144 | 295 | 185 | 61 | 42 | 144 | 235 | 3 | 180 | 29.1 |
| page=4K cache=16M mmap=256M nomutex | 434 | 150 | 304 | 182 | 58 | 41 | 140 | 223 | 2 | 200 | 29.2 |

### pragmas: medium/ytid (20k), hash64 rowid, no index, text json
| config | insertBulk | insertSingle | updateBulk | get | getNoDecode | contains | getAll | loadAllKeyed | loadKeys | delHalf | sizeMB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| page=4K | 808 | 315 | 369 | 249 | 115 | 107 | 206 | 266 | 31 | 269 | 33.1 |
| page=4K cache=16M | 587 | 333 | 340 | 225 | 115 | 99 | 207 | 309 | 35 | 261 | 33.1 |
| page=4K mmap=256M | 830 | 316 | 369 | 171 | 52 | 43 | 134 | 226 | 5 | 254 | 33.1 |
| page=4K cache=16M mmap=256M | 598 | 334 | 362 | 172 | 51 | 44 | 134 | 227 | 5 | 246 | 33.1 |
| page=8K cache=16M mmap=256M | 565 | 306 | 351 | 171 | 53 | 43 | 142 | 236 | 5 | 202 | 33.4 |
| page=4K cache=16M mmap=256M nomutex | 618 | 332 | 357 | 175 | 50 | 42 | 130 | 223 | 4 | 216 | 33.1 |

### pragmas: large/ytid (4k), rowid + text key index (current), text json
| config | insertBulk | insertSingle | updateBulk | get | getNoDecode | contains | getAll | loadAllKeyed | loadKeys | delHalf | sizeMB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| page=4K | 861 | 100 | 467 | 419 | 176 | 8 | 417 | 540 | 1 | 30 | 71.0 |
| page=4K cache=16M | 2382 | 280 | 466 | 425 | 175 | 8 | 465 | 566 | 1 | 35 | 71.0 |
| page=4K mmap=256M | 2171 | 275 | 479 | 398 | 139 | 8 | 380 | 531 | 1 | 27 | 71.0 |
| page=4K cache=16M mmap=256M | 803 | 101 | 484 | 391 | 142 | 8 | 366 | 500 | 1 | 21 | 71.0 |
| page=8K cache=16M mmap=256M | 732 | 103 | 445 | 379 | 133 | 8 | 367 | 491 | 1 | 17 | 73.2 |
| page=4K cache=16M mmap=256M nomutex | 834 | 110 | 515 | 412 | 154 | 8 | 373 | 495 | 0 | 22 | 71.0 |

### pragmas: large/ytid (4k), hash64 rowid, no index, text json
| config | insertBulk | insertSingle | updateBulk | get | getNoDecode | contains | getAll | loadAllKeyed | loadKeys | delHalf | sizeMB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| page=4K | 1100 | 159 | 573 | 474 | 214 | 15 | 506 | 596 | 4 | 39 | 71.2 |
| page=4K cache=16M | 872 | 140 | 489 | 442 | 191 | 9 | 461 | 558 | 1 | 29 | 71.2 |
| page=4K mmap=256M | 869 | 141 | 506 | 380 | 136 | 8 | 375 | 505 | 1 | 23 | 71.2 |
| page=4K cache=16M mmap=256M | 924 | 140 | 491 | 396 | 139 | 8 | 379 | 513 | 1 | 21 | 71.2 |
| page=8K cache=16M mmap=256M | 804 | 138 | 498 | 395 | 138 | 9 | 381 | 532 | 1 | 18 | 73.7 |
| page=4K cache=16M mmap=256M nomutex | 964 | 143 | 500 | 406 | 144 | 8 | 392 | 526 | 1 | 18 | 71.2 |

### codec: small/ytid (100k), rowid + text key index (current), page=4K cache=16M mmap=256M
| config | insertBulk | insertSingle | updateBulk | get | getNoDecode | contains | getAll | loadAllKeyed | loadKeys | delHalf | sizeMB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| text json | 383 | 119 | 284 | 395 | 298 | 220 | 240 | 170 | 17 | 251 | 17.5 |
| text, read bytes+fused | 381 | 118 | 278 | 366 | 289 | 230 | 225 | 162 | 21 | 251 | 17.5 |
| text, utf8 bytes both ways | 342 | 113 | 246 | 372 | 294 | 224 | 221 | 161 | 15 | 262 | 17.5 |
| blob utf8 json | 371 | 131 | 243 | 379 | 305 | 227 | 225 | 153 | 21 | 288 | 17.5 |
| blob jsonb | 432 | 127 | 314 | 465 | 340 | 272 | 325 | 243 | 17 | 250 | 16.5 |

### codec: small/path (100k), rowid + text key index (current), page=4K cache=16M mmap=256M
| config | insertBulk | insertSingle | updateBulk | get | getNoDecode | contains | getAll | loadAllKeyed | loadKeys | delHalf | sizeMB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| text json | 1692 | 600 | 433 | 489 | 392 | 288 | 337 | 197 | 24 | 1862 | 35.0 |
| text, read bytes+fused | 1153 | 170 | 375 | 453 | 366 | 290 | 317 | 179 | 18 | 867 | 35.0 |
| text, utf8 bytes both ways | 642 | 178 | 365 | 479 | 380 | 307 | 333 | 180 | 23 | 826 | 35.0 |
| blob utf8 json | 590 | 179 | 353 | 454 | 386 | 302 | 342 | 186 | 26 | 846 | 35.0 |
| blob jsonb | 632 | 181 | 417 | 493 | 358 | 286 | 368 | 238 | 21 | 783 | 34.7 |

### codec: medium/ytid (20k), rowid + text key index (current), page=4K cache=16M mmap=256M
| config | insertBulk | insertSingle | updateBulk | get | getNoDecode | contains | getAll | loadAllKeyed | loadKeys | delHalf | sizeMB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| text json | 451 | 151 | 309 | 184 | 59 | 42 | 144 | 222 | 3 | 207 | 29.2 |
| text, read bytes+fused | 443 | 145 | 305 | 155 | 60 | 40 | 117 | 202 | 3 | 202 | 29.2 |
| text, utf8 bytes both ways | 378 | 143 | 236 | 155 | 58 | 46 | 124 | 201 | 4 | 202 | 29.2 |
| blob utf8 json | 383 | 154 | 246 | 155 | 62 | 42 | 117 | 200 | 5 | 207 | 29.2 |
| blob jsonb | 415 | 146 | 268 | 248 | 61 | 46 | 203 | 338 | 3 | 250 | 29.2 |

### codec: large/ytid (4k), rowid + text key index (current), page=4K cache=16M mmap=256M
| config | insertBulk | insertSingle | updateBulk | get | getNoDecode | contains | getAll | loadAllKeyed | loadKeys | delHalf | sizeMB |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| text json | 806 | 105 | 481 | 364 | 132 | 8 | 353 | 492 | 1 | 22 | 71.0 |
| text, read bytes+fused | 1161 | 243 | 451 | 127 | 21 | 8 | 119 | 228 | 1 | 25 | 71.0 |
| text, utf8 bytes both ways | 2072 | 261 | 404 | 128 | 21 | 8 | 119 | 245 | 1 | 27 | 71.0 |
| blob utf8 json | 1965 | 246 | 400 | 126 | 20 | 8 | 119 | 228 | 1 | 26 | 71.0 |
| blob jsonb | 2180 | 197 | 359 | 181 | 19 | 8 | 185 | 348 | 1 | 106 | 68.9 |

### json_extract (2 paths) full scan, ms, page=4K cache=16M mmap=256M
| dataset | text json | text via bytes | blob utf8 json | jsonb |
|---|---:|---:|---:|---:|
| medium/ytid (20k) | 47 | 42 | 83 | 8 |
| large/ytid (4k) | 48 | 45 | 82 | 5 |

### binding: upsert all keys in one transaction, values pre-encoded, ms, page=4K cache=16M mmap=256M
| dataset | execute([key, text]) | raw bindText x2 | raw bindText + bindBlob CAST |
|---|---:|---:|---:|
| small/ytid (100k) | 243 | 246 | 214 |
| large/ytid (4k) | 474 | 491 | 346 |

### hive_ce (same datasets)
| hive_ce | putAll | 2000 single puts | get (Box, in-memory) | get (LazyBox, awaited) | reopen Box (= load all) | sizeMB |
|---|---:|---:|---:|---:|---:|---:|
| small/ytid (100k) | 308 | 63 | 125 | 4768 | 404 | 15.5 |
| small/path (100k) | 688 | 71 | 405 | 5667 | 859 | 23.5 |
| large/ytid (4k) | 573 | 336 | 2 | 543 | 646 | 100.6 |

### isolate round trip
Timer cancel+create: 1.319 µs/op
Stopwatch timestamp (alternative): 0.032 µs/op (9709)

| payload | sync decode only | async: decoded map back (current) | async: bytes back + decode on main | async: transferable + decode on main | awaited one by one vs Future.wait |
|---|---:|---:|---:|---:|---:|
| small (129B) | 0.5 µs | 7.5 µs | 7.1 µs | 11.8 µs | 7.5 µs vs 2.2 µs |
| medium (1.3KB) | 4.1 µs | 14.0 µs | 11.6 µs | 13.2 µs | 14.0 µs vs 9.1 µs |
| large (16.5KB) | 24.9 µs | 42.1 µs | 37.9 µs | 45.3 µs | 42.1 µs vs 56.5 µs |
isolate terminated by Isolate.kill
