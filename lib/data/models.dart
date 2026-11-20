/// Data models for the library.
library;

class BookMeta {
  BookMeta({
    required this.id,
    required this.title,
    required this.category,
    required this.sections,
    required this.paragraphs,
    required this.chars,
  });

  factory BookMeta.fromJson(Map<String, dynamic> j) {
    final stats = (j['stats'] as Map).cast<String, dynamic>();
    return BookMeta(
      id: j['id'] as String,
      title: j['title'] as String,
      category: j['category'] as String,
      sections: stats['sections'] as int,
      paragraphs: stats['paragraphs'] as int,
      chars: stats['chars'] as int,
    );
  }

  final String id;
  final String title;
  final String category;
  final int sections;
  final int paragraphs;
  final int chars;
}

class Section {
  Section(this.title, this.level, this.paragraphs);

  final String title;
  final int level;
  final List<String> paragraphs;
}

/// A position inside a book.
class Loc {
  const Loc(this.section, this.para);

  final int section;
  final int para; // -1 = section heading

  Map<String, dynamic> toJson() => {'s': section, 'p': para};

  static Loc fromJson(Map j) => Loc(j['s'] as int, j['p'] as int);
}

/// One row in the reader: a heading or a paragraph.
class ReaderItem {
  const ReaderItem.heading(this.section) : para = -1;
  const ReaderItem.para(this.section, this.para);

  final int section;
  final int para;

  bool get isHeading => para < 0;
}

class Book {
  Book(this.meta, this.sections) {
    for (var s = 0; s < sections.length; s++) {
      final sec = sections[s];
      _sectionStart.add(items.length);
      if (sec.title.isNotEmpty) items.add(ReaderItem.heading(s));
      for (var p = 0; p < sec.paragraphs.length; p++) {
        items.add(ReaderItem.para(s, p));
      }
    }
  }

  final BookMeta meta;
  final List<Section> sections;
  final List<ReaderItem> items = [];
  final List<int> _sectionStart = [];

  int indexOf(Loc loc) {
    if (loc.section < 0 || loc.section >= sections.length) return 0;
    final start = _sectionStart[loc.section];
    if (loc.para < 0) return start;
    final hasHeading = sections[loc.section].title.isNotEmpty;
    return (start + (hasHeading ? 1 : 0) + loc.para).clamp(0, items.length - 1);
  }

  Loc locOf(int index) {
    if (items.isEmpty) return const Loc(0, -1);
    final it = items[index.clamp(0, items.length - 1)];
    return Loc(it.section, it.para);
  }

  /// Breadcrumb of section titles leading to [section] (parents first).
  List<String> breadcrumb(int section) {
    final out = <String>[];
    var level = 1 << 30;
    for (var s = section; s >= 0; s--) {
      final sec = sections[s];
      if (sec.level < level && sec.title.isNotEmpty) {
        out.insert(0, sec.title);
        level = sec.level;
        if (level == 0) break;
      }
    }
    return out;
  }
}

class Bookmark {
  Bookmark({
    required this.bookId,
    required this.loc,
    required this.label,
    required this.snippet,
    required this.created,
  });

  factory Bookmark.fromJson(Map j) => Bookmark(
        bookId: j['b'] as String,
        loc: Loc.fromJson(j['l'] as Map),
        label: j['t'] as String,
        snippet: j['x'] as String,
        created: DateTime.fromMillisecondsSinceEpoch(j['c'] as int),
      );

  final String bookId;
  final Loc loc;
  final String label;
  final String snippet;
  final DateTime created;

  Map<String, dynamic> toJson() => {
        'b': bookId,
        'l': loc.toJson(),
        't': label,
        'x': snippet,
        'c': created.millisecondsSinceEpoch,
      };
}

class SearchHit {
  SearchHit(this.book, this.section, this.para);

  final Book book;
  final int section;
  final int para;
}

/// A personal note the reader attached to a paragraph (optionally to a quoted part of it).
class Note {
  Note({
    required this.id,
    required this.bookId,
    required this.loc,
    required this.text,
    required this.label,
    required this.created,
    required this.updated,
    this.quote = '',
  });

  factory Note.fromJson(Map j) => Note(
        id: (j['i'] ?? j['c']) as int,
        bookId: j['b'] as String,
        loc: Loc.fromJson(j['l'] as Map),
        text: j['x'] as String,
        label: (j['t'] as String?) ?? '',
        quote: (j['q'] as String?) ?? '',
        created: DateTime.fromMillisecondsSinceEpoch(j['c'] as int),
        updated: DateTime.fromMillisecondsSinceEpoch((j['u'] ?? j['c']) as int),
      );

  final int id;
  final String bookId;
  final Loc loc;
  String text;
  final String label;
  final String quote;
  final DateTime created;
  DateTime updated;

  Map<String, dynamic> toJson() => {
        'i': id,
        'b': bookId,
        'l': loc.toJson(),
        'x': text,
        't': label,
        'q': quote,
        'c': created.millisecondsSinceEpoch,
        'u': updated.millisecondsSinceEpoch,
      };
}
