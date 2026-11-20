import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../platform/platform.dart';
import 'hebrew.dart';
import 'models.dart';

/// Loads the catalog and book contents bundled with the app.
class Library {
  Library._(this.categories, this.books);

  final List<String> categories;
  final List<BookMeta> books;
  final Map<String, Book> _cache = {};
  final Map<String, Future<Book>> _pending = {};

  late final Map<String, BookMeta> byId = {for (final b in books) b.id: b};

  static Future<Library> load() async {
    final raw = await rootBundle.loadString('assets/catalog.json');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final books = (j['books'] as List)
        .map((e) => BookMeta.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final cats = (j['categories'] as List).cast<String>();
    final extra = books.map((b) => b.category).where((c) => !cats.contains(c)).toSet();
    return Library._([...cats.where((c) => books.any((b) => b.category == c)), ...extra], books);
  }


  Book? cached(String id) => _cache[id];

  Future<Book> book(String id) {
    final c = _cache[id];
    if (c != null) return Future.value(c);
    return _pending[id] ??= _load(id).whenComplete(() {
      _pending.remove(id);
    });
  }

  Future<Book> _load(String id) async {
    final meta = byId[id]!;
    final data = await rootBundle.load('assets/books/$id.json.gz');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    final text = utf8.decode(gunzipBytes(bytes));
    final j = jsonDecode(text) as Map<String, dynamic>;
    final sections = (j['sections'] as List).map((s) {
      final m = s as Map;
      return Section(m['t'] as String, m['l'] as int, (m['p'] as List).cast<String>());
    }).toList();
    final book = Book(meta, sections);
    _cache[id] = book;
    return book;
  }
}

class SearchResult {
  SearchResult(this.hits, this.perBook, this.truncated, this.terms, this.elapsed);

  final List<SearchHit> hits;
  final Map<String, int> perBook;
  final bool truncated;
  final List<String> terms;
  final Duration elapsed;
}

class _BookIndex {
  _BookIndex(this.book, this.norm, this.sec, this.para);

  final Book book;
  final List<String> norm;
  final List<int> sec;
  final List<int> para;
}

/// Full-text search over every book. Niqqud- and punctuation-insensitive.
/// Runs on the UI isolate but yields regularly, so it works on all platforms.
class SearchEngine {
  SearchEngine(this.library);

  final Library library;
  final List<_BookIndex> _index = [];
  Future<void>? _building;
  final ValueNotifier<double> progress = ValueNotifier(0);

  bool get ready => _index.length == library.books.length;

  Future<void> ensureBuilt() => _building ??= _build();

  Future<void> _build() async {
    var done = 0;
    for (final meta in library.books) {
      final book = await library.book(meta.id);
      final norm = <String>[], sec = <int>[], para = <int>[];
      for (var s = 0; s < book.sections.length; s++) {
        final ps = book.sections[s].paragraphs;
        for (var p = 0; p < ps.length; p++) {
          norm.add(normalizeForSearch(ps[p]));
          sec.add(s);
          para.add(p);
        }
      }
      _index.add(_BookIndex(book, norm, sec, para));
      done++;
      progress.value = done / library.books.length;
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<SearchResult> search(String query, {Set<String>? bookIds, int limit = 2500}) async {
    final sw = Stopwatch()..start();
    await ensureBuilt();
    final terms = queryTerms(query);
    final hits = <SearchHit>[];
    final perBook = <String, int>{};
    var truncated = false;
    if (terms.isEmpty) return SearchResult(hits, perBook, false, terms, sw.elapsed);
    var work = 0;
    for (final bi in _index) {
      if (bookIds != null && !bookIds.contains(bi.book.meta.id)) continue;
      var count = 0;
      final norm = bi.norm;
      for (var i = 0; i < norm.length; i++) {
        final t = norm[i];
        var ok = true;
        for (final term in terms) {
          if (!t.contains(term)) {
            ok = false;
            break;
          }
        }
        if (ok) {
          count++;
          if (hits.length < limit) {
            hits.add(SearchHit(bi.book, bi.sec[i], bi.para[i]));
          } else {
            truncated = true;
          }
        }
        work += t.length;
        if (work > 3000000) {
          work = 0;
          await Future<void>.delayed(Duration.zero);
        }
      }
      if (count > 0) perBook[bi.book.meta.id] = count;
    }
    return SearchResult(hits, perBook, truncated, terms, sw.elapsed);
  }
}
