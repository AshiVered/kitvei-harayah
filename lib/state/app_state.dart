import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/library.dart';
import '../data/models.dart';

enum ReaderFont { frank, david, system }

extension ReaderFontX on ReaderFont {
  String get family => switch (this) {
        ReaderFont.frank => 'FrankRuhlLibre',
        ReaderFont.david => 'DavidLibre',
        ReaderFont.system => 'Segoe UI',
      };
  String get label => switch (this) {
        ReaderFont.frank => 'פרנק־רוהל',
        ReaderFont.david => 'דוד',
        ReaderFont.system => 'גופן המערכת',
      };
}

class LastRead {
  LastRead(this.bookId, this.loc, this.progress, this.at);

  factory LastRead.fromJson(Map j) => LastRead(
        j['b'] as String,
        Loc.fromJson(j['l'] as Map),
        (j['g'] as num).toDouble(),
        DateTime.fromMillisecondsSinceEpoch(j['a'] as int),
      );

  final String bookId;
  final Loc loc;
  final double progress;
  final DateTime at;

  Map<String, dynamic> toJson() =>
      {'b': bookId, 'l': loc.toJson(), 'g': progress, 'a': at.millisecondsSinceEpoch};
}

/// Global application state: settings, bookmarks, notes and reading history.
class AppState extends ChangeNotifier {
  AppState(this.library, this._prefs, {this.persistent = true}) : search = SearchEngine(library) {
    if (persistent) _restore();
  }

  /// False on the web: nothing personal is stored (no bookmarks, notes, history or backup),
  /// and display settings last only until the visitor leaves the site.
  final bool persistent;

  /// Bookmarks, notes and history are desktop-only features.
  bool get personalData => persistent;

  SharedPreferences? get _store => persistent ? _prefs : null;

  final Library library;
  final SearchEngine search;
  final SharedPreferences _prefs;

  ThemeMode themeMode = ThemeMode.system;
  ReaderFont font = ReaderFont.frank;
  double fontSize = 22;
  double lineHeight = 1.85;
  bool showNiqqud = true;
  bool justify = true;
  final List<Bookmark> bookmarks = [];
  final List<Note> notes = [];
  final Map<String, LastRead> history = {};
  Timer? _saveTimer;

  static Future<AppState> create() async {
    final lib = await Library.load();
    final prefs = await SharedPreferences.getInstance();
    return AppState(lib, prefs, persistent: !kIsWeb);
  }

  void _restore() {
    try {
      themeMode = ThemeMode.values[(_prefs.getInt('themeMode') ?? 0).clamp(0, 2)];
      font = ReaderFont.values[(_prefs.getInt('font') ?? 0).clamp(0, ReaderFont.values.length - 1)];
      fontSize = _prefs.getDouble('fontSize') ?? fontSize;
      lineHeight = _prefs.getDouble('lineHeight') ?? lineHeight;
      showNiqqud = _prefs.getBool('niqqud') ?? true;
      justify = _prefs.getBool('justify') ?? true;
      final bm = _prefs.getString('bookmarks');
      if (bm != null) {
        bookmarks.addAll((jsonDecode(bm) as List)
            .map((e) => Bookmark.fromJson(e as Map))
            .where((b) => library.byId.containsKey(b.bookId)));
      }
      final n = _prefs.getString('notes');
      if (n != null) {
        notes.addAll((jsonDecode(n) as List)
            .map((e) => Note.fromJson(e as Map))
            .where((x) => library.byId.containsKey(x.bookId)));
      }
      final h = _prefs.getString('history');
      if (h != null) {
        (jsonDecode(h) as Map).forEach((k, v) {
          if (library.byId.containsKey(k)) history[k as String] = LastRead.fromJson(v as Map);
        });
      }
    } catch (_) {
      // Corrupt preferences: start fresh.
    }
  }

  void _persistSettings() {
    _store?.setInt('themeMode', themeMode.index);
    _store?.setInt('font', font.index);
    _store?.setDouble('fontSize', fontSize);
    _store?.setDouble('lineHeight', lineHeight);
    _store?.setBool('niqqud', showNiqqud);
    _store?.setBool('justify', justify);
  }

  void update(void Function(AppState s) change) {
    change(this);
    _persistSettings();
    notifyListeners();
  }

  // ---- bookmarks ----
  bool isBookmarked(String bookId, Loc loc) =>
      bookmarks.any((b) => b.bookId == bookId && b.loc.section == loc.section && b.loc.para == loc.para);

  void toggleBookmark(Book book, Loc loc) {
    final i = bookmarks.indexWhere(
        (b) => b.bookId == book.meta.id && b.loc.section == loc.section && b.loc.para == loc.para);
    if (i >= 0) {
      bookmarks.removeAt(i);
    } else {
      final sec = book.sections[loc.section];
      final text = loc.para >= 0 && loc.para < sec.paragraphs.length
          ? sec.paragraphs[loc.para]
          : (sec.paragraphs.isNotEmpty ? sec.paragraphs.first : '');
      bookmarks.insert(
        0,
        Bookmark(
          bookId: book.meta.id,
          loc: loc,
          label: book.breadcrumb(loc.section).join(' · '),
          snippet: text.length > 220 ? '${text.substring(0, 220)}…' : text,
          created: DateTime.now(),
        ),
      );
    }
    _store?.setString('bookmarks', jsonEncode(bookmarks.map((b) => b.toJson()).toList()));
    notifyListeners();
  }

  void removeBookmark(Bookmark b) {
    bookmarks.remove(b);
    _store?.setString('bookmarks', jsonEncode(bookmarks.map((b) => b.toJson()).toList()));
    notifyListeners();
  }

  // ---- notes ----
  List<Note> notesAt(String bookId, Loc loc) => [
        for (final n in notes)
          if (n.bookId == bookId && n.loc.section == loc.section && n.loc.para == loc.para) n,
      ];

  Note addNote(Book book, Loc loc, String text, {String quote = ''}) {
    final now = DateTime.now();
    final n = Note(
      id: now.microsecondsSinceEpoch,
      bookId: book.meta.id,
      loc: loc,
      text: text.trim(),
      quote: quote.trim(),
      label: book.breadcrumb(loc.section).join(' · '),
      created: now,
      updated: now,
    );
    notes.insert(0, n);
    _saveNotes();
    notifyListeners();
    return n;
  }

  /// Updates a note's text; empty text deletes it.
  void updateNote(Note n, String text) {
    if (text.trim().isEmpty) {
      notes.remove(n);
    } else {
      n
        ..text = text.trim()
        ..updated = DateTime.now();
    }
    _saveNotes();
    notifyListeners();
  }

  void removeNote(Note n) {
    notes.remove(n);
    _saveNotes();
    notifyListeners();
  }

  void _saveNotes() => _store?.setString('notes', jsonEncode(notes.map((n) => n.toJson()).toList()));

  // ---- backup ----
  static const backupFormat = 'kitvei-harayah-backup';

  Map<String, dynamic> exportData(String appVersion) => {
        'format': backupFormat,
        'formatVersion': 1,
        'appVersion': appVersion,
        'exported': DateTime.now().toIso8601String(),
        'settings': {
          'themeMode': themeMode.index,
          'font': font.index,
          'fontSize': fontSize,
          'lineHeight': lineHeight,
          'niqqud': showNiqqud,
          'justify': justify,
        },
        'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
        'notes': notes.map((n) => n.toJson()).toList(),
        'history': history.map((k, v) => MapEntry(k, v.toJson())),
      };

  /// Replaces settings, bookmarks, notes and history with the backup's contents.
  /// Throws [FormatException] if [data] is not a backup of this app.
  void importData(Map<String, dynamic> data) {
    if (data['format'] != backupFormat) throw const FormatException('הקובץ אינו קובץ גיבוי של כתבי הראי״ה');
    final st = (data['settings'] as Map?) ?? const {};
    final newBookmarks = ((data['bookmarks'] as List?) ?? const [])
        .map((e) => Bookmark.fromJson(e as Map))
        .where((b) => library.byId.containsKey(b.bookId))
        .toList();
    final newNotes = ((data['notes'] as List?) ?? const [])
        .map((e) => Note.fromJson(e as Map))
        .where((n) => library.byId.containsKey(n.bookId))
        .toList();
    final newHistory = <String, LastRead>{};
    ((data['history'] as Map?) ?? const {}).forEach((k, v) {
      if (library.byId.containsKey(k)) newHistory[k as String] = LastRead.fromJson(v as Map);
    });
    themeMode = ThemeMode.values[((st['themeMode'] as num?)?.toInt() ?? themeMode.index).clamp(0, 2)];
    font = ReaderFont.values[((st['font'] as num?)?.toInt() ?? font.index).clamp(0, ReaderFont.values.length - 1)];
    fontSize = (st['fontSize'] as num?)?.toDouble() ?? fontSize;
    lineHeight = (st['lineHeight'] as num?)?.toDouble() ?? lineHeight;
    showNiqqud = (st['niqqud'] as bool?) ?? showNiqqud;
    justify = (st['justify'] as bool?) ?? justify;
    bookmarks
      ..clear()
      ..addAll(newBookmarks);
    notes
      ..clear()
      ..addAll(newNotes);
    history
      ..clear()
      ..addAll(newHistory);
    _persistSettings();
    _store?.setString('bookmarks', jsonEncode(bookmarks.map((b) => b.toJson()).toList()));
    _saveNotes();
    _store?.setString('history', jsonEncode(history.map((k, v) => MapEntry(k, v.toJson()))));
    notifyListeners();
  }

  // ---- reading history ----
  List<LastRead> get recent {
    final l = history.values.toList()..sort((a, b) => b.at.compareTo(a.at));
    return l;
  }

  void recordPosition(String bookId, Loc loc, double progress) {
    if (!persistent) return; // no reading history on the web
    history[bookId] = LastRead(bookId, loc, progress, DateTime.now());
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), () {
      _store?.setString('history', jsonEncode(history.map((k, v) => MapEntry(k, v.toJson()))));
      notifyListeners();
    });
  }

  void clearHistory(String bookId) {
    history.remove(bookId);
    _store?.setString('history', jsonEncode(history.map((k, v) => MapEntry(k, v.toJson()))));
    notifyListeners();
  }
}

/// Makes [AppState] available to the widget tree.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
