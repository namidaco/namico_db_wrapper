// by claude

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'sample_large_object.dart';

const _kBase64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
const _kYtIdLastChars = 'AEIMQUYcgkosw048';
const _kWords = [
  'Lost', 'Sky', 'Need', 'You', 'Dreams', 'Fade', 'Alan', 'Walker', 'Faded', 'Spectre', 'Nightcore', 'Remix', 'Live', //
  'Acoustic', 'Symphony', 'Echoes', 'Midnight', 'City', 'Lights', 'Ocean', 'Eyes', 'Billie', 'Ghost', 'Heart', 'Shadow', //
  'Paradise', 'Coldplay', 'Viva', 'La', 'Vida', 'Daft', 'Punk', 'Random', 'Access', 'Memories', 'Get', 'Lucky', 'Starboy', //
];

final _utf8JsonEncoder = JsonUtf8Encoder();
final _utf8JsonDecoder = utf8.decoder.fuse(json.decoder);

Uint8List utf8JsonEncode(Object v) => _utf8JsonEncoder.convert(v) as Uint8List;
Object? utf8JsonDecode(List<int> v) => _utf8JsonDecoder.convert(v);

String randomYtId(Random r) {
  final sb = StringBuffer();
  for (int i = 0; i < 10; i++) {
    sb.writeCharCode(_kBase64Chars.codeUnitAt(r.nextInt(64)));
  }
  sb.writeCharCode(_kYtIdLastChars.codeUnitAt(r.nextInt(16)));
  return sb.toString();
}

String _randomWords(Random r, int count) {
  final words = List.generate(count, (_) => _kWords[r.nextInt(_kWords.length)]);
  return words.join(' ');
}

String randomPath(Random r) {
  final artist = _randomWords(r, 2);
  final album = _randomWords(r, 3);
  final title = _randomWords(r, 4);
  final trackNumber = (r.nextInt(20) + 1).toString().padLeft(2, '0');
  final suffixNumber = r.nextInt(100000);
  return 'C:\\Users\\user\\Music\\$artist\\$album\\$trackNumber - $title ($suffixNumber).m4a';
}

List<String> generateKeys(int count, String Function(Random r) keyGen, int seed) {
  final r = Random(seed);
  final keys = <String>{};
  while (keys.length < count) {
    keys.add(keyGen(r));
  }
  return keys.toList();
}

Map<String, dynamic> smallValue(Random r) => {
      'title': _randomWords(r, 3),
      'artist': _randomWords(r, 2),
      'count': r.nextInt(500),
      'lastPlayed': 1700000000000 + r.nextInt(1 << 30),
      'rating': r.nextDouble(),
      'fav': r.nextBool(),
    };

Map<String, dynamic> mediumValue(Random r) => {
      'id': randomYtId(r),
      'title': _randomWords(r, 6),
      'channel': {'id': 'UC${randomYtId(r)}${randomYtId(r)}', 'name': _randomWords(r, 2), 'subs': r.nextInt(1 << 30)},
      'tags': List.generate(12, (_) => _randomWords(r, 2)),
      'related': List.generate(
        10,
        (_) => {'id': randomYtId(r), 'title': _randomWords(r, 5), 'views': r.nextInt(1 << 31), 'dur': r.nextInt(900)},
      ),
    };

final _largeValueBase = jsonDecode(jsonEncode(vCgMeNCFLEU_Map)) as Map<String, dynamic>;

Map<String, dynamic> largeValue(Random r) => {..._largeValueBase, 'n': r.nextInt(1 << 30)};

double timeMs(void Function() fn) {
  final sw = Stopwatch()..start();
  fn();
  sw.stop();
  return sw.elapsedMicroseconds / 1000;
}

Future<double> timeMsAsync(Future<void> Function() fn) async {
  final sw = Stopwatch()..start();
  await fn();
  sw.stop();
  return sw.elapsedMicroseconds / 1000;
}

double bestOf(int count, void Function() fn) {
  double best = double.infinity;
  for (int i = 0; i < count; i++) {
    final ms = timeMs(fn);
    best = min(best, ms);
  }
  return best;
}
