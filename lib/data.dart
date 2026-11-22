import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Version of the dictionary data. Raise it when a new data release is published
/// (a GitHub Release named data-v<number>); installed apps then offer the update.
const int kDataVersion = 2;

/// Where the dictionary database is downloaded from (GitHub Release).
const String kDataUrl =
    'https://github.com/azadrifat/german-dictionary/releases/download/data-v$kDataVersion/dictionary.db.gz';

/// One row in a result list.
class Hit {
  Hit({
    required this.id,
    required this.word,
    required this.pos,
    this.article,
    this.gender,
    required this.glosses,
  });

  final int id;
  final String word;
  final String pos;
  final String? article;
  final String? gender;
  final List<String> glosses;

  String get title => article == null ? word : '$article $word';

  factory Hit.fromRow(Map<String, Object?> r) {
    List<String> g = <String>[];
    final raw = r['glosses'];
    if (raw is String && raw.isNotEmpty) {
      try {
        g = (jsonDecode(raw) as List).map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return Hit(
      id: r['id'] as int,
      word: r['word'] as String,
      pos: (r['pos'] as String?) ?? '',
      article: r['article'] as String?,
      gender: r['gender'] as String?,
      glosses: g,
    );
  }
}

/// Builds a full-text query such as "to give" -> "to* give*".
String? ftsQuery(String q) {
  final tokens = q
      .split(RegExp(r'\s+'))
      .map((t) => t.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''))
      .where((t) => t.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return null;
  return tokens.map((t) => '$t*').join(' ');
}

const Map<String, String> _foldMap = {
  'ä': 'a',
  'ö': 'o',
  'ü': 'u',
  'ß': 'ss',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'å': 'a',
  'ç': 'c',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ý': 'y',
  'ÿ': 'y',
};

/// Lower case and strip accents: "Über" -> "uber", "Straße" -> "strasse".
String foldText(String s) {
  final b = StringBuffer();
  for (final rune in s.toLowerCase().runes) {
    final c = String.fromCharCode(rune);
    b.write(_foldMap[c] ?? c);
  }
  return b.toString();
}

/// "sich freuen" -> "freuen", "die Tasse" -> "tasse".
String normalizeGerman(String q) {
  for (final prefix in const [
    'sich ',
    'der ',
    'die ',
    'das ',
    'ein ',
    'eine '
  ]) {
    if (q.startsWith(prefix) && q.length > prefix.length) {
      return q.substring(prefix.length).trim();
    }
  }
  return q;
}

/// What a user may have meant: as typed, without accents, with ae/oe/ue -> ä/ö/ü.
List<String> queryVariants(String q) {
  final umlaut =
      q.replaceAll('ae', 'ä').replaceAll('oe', 'ö').replaceAll('ue', 'ü');
  return <String>{q, foldText(q), umlaut}.toList();
}

class Store extends ChangeNotifier {
  Database? _db;
  SharedPreferences? _prefs;

  Database get db => _db!;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<String> _dir() async => (await getApplicationSupportDirectory()).path;
  Future<String> dbPath() async => p.join(await _dir(), 'dictionary.db');
  Future<bool> hasDb() async => File(await dbPath()).exists();

  /// Which data version is installed (1 = the first release, before versions existed).
  int get dataVersion => _prefs?.getInt('dataVersion') ?? 1;

  Future<void> openDb() async {
    _db = await openDatabase(await dbPath(), readOnly: true);
  }

  /// Downloads dictionary.db.gz and unpacks it. [onProgress] gets a fraction
  /// (null = unknown) and a message.
  Future<void> download(
    void Function(double? fraction, String message) onProgress,
  ) async {
    final dir = await _dir();
    final gzPath = p.join(dir, 'dictionary.db.gz');
    final outPath = p.join(dir, 'dictionary.db');
    final tmpPath = '$outPath.tmp';

    final client = http.Client();
    try {
      final response =
          await client.send(http.Request('GET', Uri.parse(kDataUrl)));
      if (response.statusCode != 200) {
        throw Exception('Download failed (HTTP ${response.statusCode})');
      }
      final total = response.contentLength;
      var got = 0;
      var lastTick = -1;
      final sink = File(gzPath).openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
        got += chunk.length;
        if (total != null && total > 0) {
          final tick = (got * 200 / total).floor();
          if (tick != lastTick) {
            lastTick = tick;
            final mb = (got / 1048576).toStringAsFixed(1);
            final totalMb = (total / 1048576).toStringAsFixed(1);
            onProgress(got / total, 'Downloading $mb of $totalMb MB');
          }
        }
      }
      await sink.close();

      onProgress(null, 'Unpacking, please wait...');
      await File(gzPath)
          .openRead()
          .transform(gzip.decoder)
          .pipe(File(tmpPath).openWrite());
      await File(tmpPath).rename(outPath);
      await File(gzPath).delete();
      await _prefs?.setInt('dataVersion', kDataVersion);
    } finally {
      client.close();
    }
  }

  // ------------------------------------------------------------ search
  // Keep in sync with dict_search.py (the tests use that copy).
  Future<List<Hit>> search(String raw) async {
    final lower = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (lower.isEmpty) return <Hit>[];
    final de = normalizeGerman(lower);
    final en = lower.replaceFirst(RegExp(r'^(to|a|an|the)\s+'), '');
    final variants = <String>{...queryVariants(de), lower}.toList();

    final seen = <int>{};
    final out = <Hit>[];

    void add(List<Map<String, Object?>> rows) {
      for (final r in rows) {
        if (seen.add(r['id'] as int)) out.add(Hit.fromRow(r));
      }
    }

    const cols = 'e.id, e.word, e.pos, e.article, e.gender, e.glosses';

    // 1. exact German word or inflected form ("ging" -> gehen), also
    //    spelled without umlauts ("uber", "ueber" -> über, "strasse" -> Straße)
    final marks = List<String>.filled(variants.length, '?').join(',');
    add(await db.rawQuery(
      'SELECT $cols, MIN(l.rank) AS r FROM lookup l '
      'JOIN entries e ON e.id = l.entry_id WHERE l.form IN ($marks) '
      'GROUP BY e.id ORDER BY r, e.freq DESC LIMIT 25',
      variants,
    ));

    // 2. German words that start with what was typed
    if (de.length >= 2) {
      for (final pre in <String>{de, foldText(de)}) {
        add(await db.rawQuery(
          'SELECT $cols FROM lookup l JOIN entries e ON e.id = l.entry_id '
          'WHERE l.form >= ? AND l.form < ? '
          'AND (l.rank <= 1 OR l.rank BETWEEN 4 AND 5) '
          'GROUP BY e.id ORDER BY e.freq DESC LIMIT 25',
          [pre, '$pre\uffff'],
        ));
      }
    }

    // 3. English meaning, exact ("ship" -> Schiff, "to give" -> geben)
    add(await db.rawQuery(
      'SELECT $cols FROM gloss_key k JOIN entries e ON e.id = k.entry_id '
      'WHERE k.key = ? ORDER BY e.freq DESC LIMIT 25',
      [en],
    ));

    // 4. English meaning, loose full-text match
    final fts = ftsQuery(en);
    if (fts != null) {
      try {
        add(await db.rawQuery(
          'SELECT $cols FROM gloss_fts f JOIN entries e ON e.id = f.docid '
          'WHERE gloss_fts MATCH ? ORDER BY e.freq DESC LIMIT 25',
          [fts],
        ));
      } catch (_) {}
    }
    return out.take(60).toList();
  }

  Future<List<Hit>> hitsFor(List<int> ids) async {
    if (ids.isEmpty) return <Hit>[];
    final marks = List<String>.filled(ids.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT id, word, pos, article, gender, glosses FROM entries '
      'WHERE id IN ($marks)',
      ids,
    );
    final byId = <int, Hit>{
      for (final r in rows) r['id'] as int: Hit.fromRow(r),
    };
    return <Hit>[
      for (final id in ids)
        if (byId.containsKey(id)) byId[id]!,
    ];
  }

  Future<Map<String, Object?>?> entry(int id) async {
    final rows = await db.rawQuery('SELECT * FROM entries WHERE id = ?', [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int?> findId(String word) async {
    final rows = await db.rawQuery(
      'SELECT e.id FROM lookup l JOIN entries e ON e.id = l.entry_id '
      'WHERE l.form = ? ORDER BY l.rank, e.freq DESC LIMIT 1',
      [word.toLowerCase()],
    );
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  // --------------------------------------------- favourites and history
  List<int> _ids(String key) =>
      (_prefs?.getStringList(key) ?? const <String>[]).map(int.parse).toList();

  Future<void> _saveIds(String key, List<int> ids) async {
    await _prefs!.setStringList(key, ids.map((e) => e.toString()).toList());
  }

  List<int> get favorites => _ids('favs');
  List<int> get recents => _ids('recent');
  bool isFavorite(int id) => favorites.contains(id);

  Map<String, int> _counts() {
    final s = _prefs?.getString('counts');
    if (s == null || s.isEmpty) return <String, int>{};
    try {
      return (jsonDecode(s) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return <String, int>{};
    }
  }

  List<int> get frequent {
    final entries = _counts().entries.where((e) => e.value >= 2).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(8).map((e) => int.parse(e.key)).toList();
  }

  Future<void> toggleFavorite(int id) async {
    final f = favorites;
    if (!f.remove(id)) f.insert(0, id);
    await _saveIds('favs', f);
    notifyListeners();
  }

  Future<void> visit(int id) async {
    final r = recents;
    r.remove(id);
    r.insert(0, id);
    if (r.length > 30) r.removeRange(30, r.length);
    await _saveIds('recent', r);
    final counts = _counts();
    counts['$id'] = (counts['$id'] ?? 0) + 1;
    await _prefs!.setString('counts', jsonEncode(counts));
    notifyListeners();
  }
}

final Store store = Store();
