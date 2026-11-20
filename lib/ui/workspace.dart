import 'package:material_ui/material_ui.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../data/hebrew.dart';
import '../data/models.dart';
import '../state/app_state.dart';

enum SidePanel { library, toc, search, bookmarks, notes }

enum TabKind { start, book, about }

/// State of one open book: position, highlights and scroll controllers.
class ReaderController extends ChangeNotifier {
  ReaderController(this.book, int initialIndex) : current = initialIndex, initialIndex = initialIndex;

  final Book book;
  final int initialIndex;
  int current;
  RegExp? highlight;
  int? flashIndex; // paragraph to emphasize after a jump
  final scroll = ItemScrollController();
  final positions = ItemPositionsListener.create();

  Loc get loc => book.locOf(current);
  double get progress => book.items.length <= 1 ? 1 : current / (book.items.length - 1);

  void setCurrent(int i) {
    if (i == current) return;
    current = i;
    notifyListeners();
  }

  void jumpTo(Loc loc, {String? highlightQuery}) {
    final idx = book.indexOf(loc);
    if (highlightQuery != null && highlightQuery.trim().isNotEmpty) {
      highlight = highlightRegex(queryTerms(highlightQuery));
      flashIndex = idx;
    }
    current = idx;
    // +1: item 0 of the reading page is its top margin.
    if (scroll.isAttached) scroll.jumpTo(index: idx + 1, alignment: 0.05);
    notifyListeners();
  }
}

class DocTab {
  DocTab.start() : kind = TabKind.start, reader = null, id = 'start';
  DocTab.about() : kind = TabKind.about, reader = null, id = 'about';
  DocTab.book(ReaderController r) : kind = TabKind.book, reader = r, id = 'book:${r.book.meta.id}';

  final String id;
  final TabKind kind;
  final ReaderController? reader;

  String get title => switch (kind) {
        TabKind.start => 'דף הבית',
        TabKind.about => 'אודות',
        TabKind.book => reader!.book.meta.title,
      };

  IconData get icon => switch (kind) {
        TabKind.start => Icons.home_outlined,
        TabKind.about => Icons.info_outline,
        TabKind.book => Icons.menu_book_outlined,
      };
}

/// The open tabs and side-panel state of the main window.
class Workspace extends ChangeNotifier {
  Workspace(this.app);

  final AppState app;
  final List<DocTab> tabs = [DocTab.start()];
  int active = 0;
  SidePanel panel = SidePanel.library;
  bool panelOpen = true;
  double panelWidth = 300;
  final searchFocus = FocusNode();

  DocTab get activeTab => tabs[active];
  ReaderController? get activeReader => activeTab.reader;

  void activate(int i) {
    if (i < 0 || i >= tabs.length || i == active) return;
    active = i;
    notifyListeners();
  }

  void cycle(int d) {
    if (tabs.length < 2) return;
    active = (active + d) % tabs.length;
    if (active < 0) active += tabs.length;
    notifyListeners();
  }

  void close(int i) {
    if (i < 0 || i >= tabs.length) return;
    tabs.removeAt(i).reader?.dispose();
    if (tabs.isEmpty) tabs.add(DocTab.start());
    if (active >= tabs.length) active = tabs.length - 1;
    if (active > i) active--;
    notifyListeners();
  }

  void showPanel(SidePanel p) {
    if (panel == p && panelOpen) {
      panelOpen = false;
    } else {
      panel = p;
      panelOpen = true;
    }
    notifyListeners();
    if (p == SidePanel.search && panelOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => searchFocus.requestFocus());
    }
  }

  void focusSearch() {
    panel = SidePanel.search;
    panelOpen = true;
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) => searchFocus.requestFocus());
  }

  void setPanelWidth(double w) {
    panelWidth = w.clamp(220, 560);
    notifyListeners();
  }

  void _openTab(DocTab t) {
    final i = tabs.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      active = i;
    } else {
      // Replace an untouched start page instead of stacking tabs.
      final insertAt = active + 1;
      tabs.insert(insertAt, t);
      active = insertAt;
    }
    notifyListeners();
  }

  void openStart() => _openTab(DocTab.start());
  void openAbout() => _openTab(DocTab.about());

  Future<void> openBook(String bookId, {Loc? at, String? highlight}) async {
    final i = tabs.indexWhere((t) => t.id == 'book:$bookId');
    if (i >= 0) {
      active = i;
      if (at != null) tabs[i].reader!.jumpTo(at, highlightQuery: highlight);
      notifyListeners();
      return;
    }
    final book = await app.library.book(bookId);
    final loc = at ?? app.history[bookId]?.loc;
    final r = ReaderController(book, loc == null ? 0 : book.indexOf(loc));
    if (highlight != null && highlight.trim().isNotEmpty) {
      r.highlight = highlightRegex(queryTerms(highlight));
      r.flashIndex = r.current;
    }
    _openTab(DocTab.book(r));
  }

  @override
  void dispose() {
    for (final t in tabs) {
      t.reader?.dispose();
    }
    searchFocus.dispose();
    super.dispose();
  }
}

class WorkspaceScope extends InheritedNotifier<Workspace> {
  const WorkspaceScope({super.key, required Workspace ws, required super.child}) : super(notifier: ws);

  static Workspace of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WorkspaceScope>()!.notifier!;

  static Workspace read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<WorkspaceScope>()!.notifier!;
}
