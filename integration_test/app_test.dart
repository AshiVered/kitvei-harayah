import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:kitvei_harayah/data/library.dart';
import 'package:kitvei_harayah/data/models.dart';
import 'package:kitvei_harayah/main.dart';
import 'package:kitvei_harayah/state/app_state.dart';
import 'package:kitvei_harayah/ui/about_view.dart';
import 'package:kitvei_harayah/ui/reader_view.dart';
import 'package:material_ui/material_ui.dart' show TextField, TextInputAction;
import 'package:shared_preferences/shared_preferences.dart';

Future<void> waitFor(WidgetTester tester, Finder f) async {
  for (var i = 0; i < 50 && f.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every book in the catalog loads', (tester) async {
    final lib = await Library.load();
    expect(lib.books.length, greaterThan(20));
    for (final m in lib.books) {
      final b = await lib.book(m.id);
      expect(b.items, isNotEmpty, reason: m.id);
    }
  });

  testWidgets('search finds a known phrase, niqqud-insensitive', (tester) async {
    final lib = await Library.load();
    final res = await SearchEngine(lib).search('ארץ ישראל איננה דבר חיצוני');
    expect(res.hits, isNotEmpty);
  });

  testWidgets('library tree → book tab → TOC, search, About', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const KitveiApp());
    await waitFor(tester, find.text('אורות התורה'));
    await tester.tap(find.text('אורות התורה').first);
    await waitFor(tester, find.byType(ReaderView));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ReaderView), findsOneWidget);

    await tester.tap(find.byTooltip('תוכן העניינים'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('חיפוש (Ctrl+K)'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).first, 'צמאון');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    for (var i = 0; i < 100 && find.textContaining('תוצאות ב').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('תוצאות ב'), findsOneWidget);

    await tester.tap(find.byTooltip('אודות'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AboutView), findsOneWidget);
    await waitFor(tester, find.text('הטקסטים'));
    expect(find.text('הטקסטים'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notes, and backup export → import round-trip', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final app = await AppState.create();
    final book = await app.library.book(app.library.books.first.id);
    final loc = book.locOf(book.items.indexWhere((i) => !i.isHeading));
    final note = app.addNote(book, loc, 'הערה לבדיקה', quote: 'ציטוט');
    app.toggleBookmark(book, loc);
    app.update((s) => s.fontSize = 30);
    expect(app.notesAt(book.meta.id, loc).single.text, 'הערה לבדיקה');

    final backup = app.exportData('test');
    app.updateNote(note, '');
    app.toggleBookmark(book, loc);
    app.update((s) => s.fontSize = 18);
    expect(app.notes, isEmpty);

    app.importData(backup);
    expect(app.notesAt(book.meta.id, loc).single.text, 'הערה לבדיקה');
    expect(app.notesAt(book.meta.id, loc).single.quote, 'ציטוט');
    expect(app.isBookmarked(book.meta.id, loc), isTrue);
    expect(app.fontSize, 30);
    expect(() => app.importData({'format': 'other'}), throwsA(isA<FormatException>()));
    expect(Loc(0, 0).toJson(), isNotEmpty);
  });
}
