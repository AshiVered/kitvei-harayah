import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../data/hebrew.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'note_dialog.dart';
import 'workspace.dart';

const _pageWidth = 820.0;

/// Phones / narrow windows: smaller margins, lighter toolbar.
bool _compact(BuildContext context) => MediaQuery.sizeOf(context).width < 720;

/// A book open in a tab: toolbar, find bar and the reading page.
class ReaderView extends StatefulWidget {
  const ReaderView({super.key, required this.controller});

  final ReaderController controller;

  @override
  State<ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<ReaderView> {
  bool _finding = false;
  String _selection = '';
  final _findCtl = TextEditingController();
  final _findFocus = FocusNode();
  List<int> _matches = [];
  int _matchIdx = -1;
  RegExp? _findRe;
  Timer? _debounce;

  ReaderController get c => widget.controller;
  Book get book => c.book;

  @override
  void initState() {
    super.initState();
    c.positions.itemPositions.addListener(_onScroll);
    c.addListener(_onController);
  }

  @override
  void dispose() {
    c.positions.itemPositions.removeListener(_onScroll);
    c.removeListener(_onController);
    _findCtl.dispose();
    _findFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onController() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    final pos = c.positions.itemPositions.value;
    if (pos.isEmpty) return;
    var best = -1;
    for (final p in pos) {
      if (p.itemTrailingEdge > 0.05 && (best < 0 || p.index < best)) {
        best = p.index;
      }
    }
    if (best < 0) return;
    final idx = (best - 1).clamp(
      0,
      book.items.length - 1,
    ); // item 0 is the page top margin
    if (idx != c.current) {
      c.setCurrent(idx);
      AppScope.read(context)
          .recordPosition(book.meta.id, book.locOf(idx), c.progress);
    }
  }

  // ---- find in book
  void _runFind(String q) {
    final terms = queryTerms(q);
    if (terms.isEmpty) {
      setState(() {
        _matches = [];
        _matchIdx = -1;
        _findRe = null;
      });
      return;
    }
    final res = <int>[];
    for (var i = 0; i < book.items.length; i++) {
      final it = book.items[i];
      final text = it.isHeading
          ? book.sections[it.section].title
          : book.sections[it.section].paragraphs[it.para];
      final n = normalizeForSearch(text);
      if (terms.every(n.contains)) res.add(i);
    }
    setState(() {
      _matches = res;
      _findRe = highlightRegex(terms);
      _matchIdx = res.isEmpty ? -1 : res.indexWhere((i) => i >= c.current);
      if (_matchIdx < 0 && res.isNotEmpty) _matchIdx = 0;
    });
    _showMatch();
  }

  void _showMatch() {
    if (_matchIdx < 0 || !c.scroll.isAttached) return;
    c.scroll.scrollTo(
      index: _matches[_matchIdx] + 1,
      alignment: 0.15,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _step(int d) {
    if (_matches.isEmpty) return;
    setState(() => _matchIdx = (_matchIdx + d) % _matches.length);
    _showMatch();
  }

  void _toggleFind() {
    setState(() {
      _finding = !_finding;
      if (!_finding) {
        _findCtl.clear();
        _matches = [];
        _findRe = null;
      }
    });
    if (_finding) _findFocus.requestFocus();
  }

  void _font(AppState app, double d) =>
      app.update((x) => x.fontSize = (x.fontSize + d).clamp(14, 40));

  Future<void> _paragraphMenu(ReaderItem it, Offset at) async {
    final app = AppScope.read(context);
    final loc = Loc(it.section, it.para);
    final raw = book.sections[it.section].paragraphs[it.para];
    final text = app.showNiqqud ? raw : stripNiqqud(raw);
    final cite = [
      book.meta.title,
      ...book.breadcrumb(it.section).map(stripNiqqud),
    ].join(', ');
    final marked = app.isBookmarked(book.meta.id, loc);
    PopupMenuItem<String> item(String v, IconData icon, String label) =>
        PopupMenuItem(
          value: v,
          height: 34,
          child: Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 10),
              Text(label),
            ],
          ),
        );
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      items: [
        if (app.personalData) ...[
          item(
            'mark',
            marked
                ? Icons.bookmark_remove_outlined
                : Icons.bookmark_add_outlined,
            marked ? 'הסרת סימנייה' : 'הוספת סימנייה',
          ),
          item('note', Icons.edit_outlined, 'הוספת הערה'),
        ],
        item('copy', Icons.copy_outlined, 'העתקת הפסקה'),
        item('cite', Icons.format_quote_outlined, 'העתקה עם מראה מקום'),
      ],
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'mark':
        app.toggleBookmark(book, loc);
      case 'note':
        await showNoteEditor(context, book, loc);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: text));
        _snack('הפסקה הועתקה');
      case 'cite':
        await Clipboard.setData(ClipboardData(text: '$text\n($cite)'));
        _snack('הועתק עם מראה מקום');
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), duration: const Duration(seconds: 2)),
  );

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = context.pal;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _toggleFind,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_finding) _toggleFind();
        },
        const SingleActivator(LogicalKeyboardKey.equal, control: true): () =>
            _font(app, 2),
        const SingleActivator(LogicalKeyboardKey.minus, control: true): () =>
            _font(app, -2),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toolbar(app, p),
            if (_finding) _findBar(p),
            Expanded(
              child: Container(color: p.page, child: _page(app, p)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(AppState app, Palette p) {
    final crumbs = book.breadcrumb(c.loc.section).map(stripNiqqud).toList();
    final marked = app.isBookmarked(book.meta.id, c.loc);
    Widget tool(
      String tip,
      Widget icon,
      VoidCallback onTap, {
      bool on = false,
    }) => IconButton(
      tooltip: tip,
      visualDensity: VisualDensity.compact,
      isSelected: on,
      style: IconButton.styleFrom(
        foregroundColor: p.muted,
        backgroundColor: on ? p.selection : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      icon: icon,
      onPressed: onTap,
    );
    return Container(
      height: 40,
      padding: const EdgeInsetsDirectional.only(start: 14, end: 6),
      decoration: BoxDecoration(
        color: p.panel,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: book.meta.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: p.accent,
                    ),
                  ),
                  for (final cr in crumbs) ...[
                    TextSpan(
                      text: '  ›  ',
                      style: TextStyle(color: p.muted),
                    ),
                    TextSpan(text: cr),
                  ],
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, color: p.ink),
            ),
          ),
          tool(
            'חיפוש בספר (Ctrl+F)',
            const Icon(Icons.search, size: 20),
            _toggleFind,
            on: _finding,
          ),
          if (app.personalData)
            tool(
              marked ? 'הסרת סימנייה' : 'סימון המקום',
              Icon(
                marked ? Icons.bookmark : Icons.bookmark_border,
                size: 20,
                color: marked ? p.gold : null,
              ),
              () => app.toggleBookmark(book, c.loc),
            ),
          if (!_compact(context))
            Container(
              width: 1,
              height: 20,
              color: p.border,
              margin: const EdgeInsets.symmetric(horizontal: 6),
            ),
          tool(
            app.showNiqqud ? 'הסתרת ניקוד' : 'הצגת ניקוד',
            Text(
              'אָ',
              style: TextStyle(
                fontFamily: textFont,
                fontSize: 19,
                color: p.ink,
              ),
            ),
            () => app.update((x) => x.showNiqqud = !x.showNiqqud),
            on: app.showNiqqud,
          ),
          tool(
            'הקטנת גופן (Ctrl+-)',
            const Icon(Icons.text_decrease, size: 20),
            () => _font(app, -2),
          ),
          if (!_compact(context))
            SizedBox(
              width: 28,
              child: Text(
                '${app.fontSize.round()}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: p.muted),
              ),
            ),
          tool(
            'הגדלת גופן (Ctrl+=)',
            const Icon(Icons.text_increase, size: 20),
            () => _font(app, 2),
          ),
        ],
      ),
    );
  }

  Widget _findBar(Palette p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      decoration: BoxDecoration(
        color: p.panelAlt,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _compact(context) ? 170 : 320,
            child: TextField(
              controller: _findCtl,
              focusNode: _findFocus,
              style: const TextStyle(fontSize: 13.5),
              decoration: const InputDecoration(
                hintText: 'חיפוש בספר זה',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
              onChanged: (q) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 300),
                  () => _runFind(q),
                );
              },
              onSubmitted: (_) => _step(1),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _findCtl.text.isEmpty
                ? ''
                : (_matches.isEmpty
                      ? 'אין תוצאות'
                      : '${_matchIdx + 1} מתוך ${_matches.length}'),
            style: TextStyle(fontSize: 12.5, color: p.muted),
          ),
          IconButton(
            tooltip: 'הקודם',
            iconSize: 20,
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: () => _step(-1),
          ),
          IconButton(
            tooltip: 'הבא (Enter)',
            iconSize: 20,
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: () => _step(1),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'סגירה (Esc)',
            iconSize: 18,
            icon: const Icon(Icons.close),
            onPressed: _toggleFind,
          ),
        ],
      ),
    );
  }

  Widget _page(AppState app, Palette p) {
    final style = TextStyle(
      fontFamily: app.font.family,
      fontSize: app.fontSize,
      height: app.lineHeight,
      color: p.ink,
    );
    final re = _findRe ?? c.highlight;
    final focused = _matchIdx >= 0 && _matchIdx < _matches.length
        ? _matches[_matchIdx]
        : c.flashIndex ?? -1;
    // Item 0 / last are the page's top and bottom margins.
    return SelectionArea(
      onSelectionChanged: (content) => _selection = content?.plainText ?? '',
      contextMenuBuilder: _selectionMenu,
      child: ScrollablePositionedList.builder(
        key: ValueKey('${book.meta.id}-${c.initialIndex}'),
        itemScrollController: c.scroll,
        itemPositionsListener: c.positions,
        initialScrollIndex: (c.current + (c.current > 0 ? 1 : 0)).clamp(
          0,
          book.items.length + 1,
        ),
        itemCount: book.items.length + 2,
        itemBuilder: (context, i) {
          final Widget child;
          if (i == 0) {
            child = const SizedBox(height: 36);
          } else if (i == book.items.length + 1) {
            child = Padding(
              padding: const EdgeInsets.only(top: 40, bottom: 60),
              child: Column(
                children: [
                  _ornament(p, 180),
                  const SizedBox(height: 8),
                  Text(
                    'תם ונשלם',
                    style: TextStyle(
                      fontFamily: textFont,
                      fontSize: 18,
                      color: p.muted,
                    ),
                  ),
                ],
              ),
            );
          } else {
            final it = book.items[i - 1];
            child = it.isHeading
                ? _heading(it, app, p)
                : _paragraph(it, app, p, style, re, i - 1 == focused);
          }
          return Center(
            child: SizedBox(
              width: _pageWidth,
              child: Padding(
                padding: _compact(context)
                    ? const EdgeInsetsDirectional.only(start: 30, end: 14)
                    : const EdgeInsets.symmetric(horizontal: 56),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }

  /// Finds the paragraph that contains (the start of) the selected text.
  Loc? _locOfSelection(String sel) {
    final key = normalizeForSearch(sel).trim();
    if (key.isEmpty) return null;
    final probe = key.length > 40 ? key.substring(0, 40) : key;
    bool matches(int i) {
      final it = book.items[i];
      return !it.isHeading &&
          normalizeForSearch(book.sections[it.section].paragraphs[it.para])
              .contains(probe);
    }

    final visible =
        c.positions.itemPositions.value
            .map((p) => p.index - 1)
            .where((i) => i >= 0 && i < book.items.length)
            .toList()
          ..sort();
    for (final i in visible) {
      if (matches(i)) return book.locOf(i);
    }
    for (var i = 0; i < book.items.length; i++) {
      if (matches(i)) return book.locOf(i);
    }
    return null;
  }

  Widget _selectionMenu(BuildContext ctx, SelectableRegionState state) {
    final p = context.pal;
    final sel = _selection.trim();
    Widget button(IconData icon, String label, VoidCallback onTap) =>
        DesktopTextSelectionToolbarButton(
          onPressed: () {
            state.hideToolbar();
            onTap();
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: p.ink),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontFamily: uiFont,
                  fontSize: 13.5,
                  color: p.ink,
                ),
              ),
            ],
          ),
        );
    final loc = _locOfSelection(sel);
    return AdaptiveTextSelectionToolbar(
      anchors: state.contextMenuAnchors,
      children: [
        if (sel.isNotEmpty &&
            loc != null &&
            AppScope.read(context).personalData)
          button(
            Icons.edit_outlined,
            'הוספת הערה',
            () => showNoteEditor(context, book, loc, quote: sel),
          ),
        if (sel.isNotEmpty)
          button(
            Icons.copy_outlined,
            'העתקה',
            () => Clipboard.setData(ClipboardData(text: sel)),
          ),
        if (sel.isNotEmpty && loc != null)
          button(Icons.format_quote_outlined, 'העתקה עם מראה מקום', () {
            final cite = [
              book.meta.title,
              ...book.breadcrumb(loc.section).map(stripNiqqud),
            ].join(', ');
            Clipboard.setData(ClipboardData(text: '$sel\n($cite)'));
            _snack('הועתק עם מראה מקום');
          }),
        button(
          Icons.select_all,
          'בחירת הכל',
          () => state.selectAll(SelectionChangedCause.toolbar),
        ),
      ],
    );
  }

  Widget _ornament(Palette p, double w) => SizedBox(
    width: w,
    child: Row(
      children: [
        Expanded(
          child: Container(height: 1, color: p.gold.withValues(alpha: 0.6)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('✦', style: TextStyle(color: p.gold, fontSize: 10)),
        ),
        Expanded(
          child: Container(height: 1, color: p.gold.withValues(alpha: 0.6)),
        ),
      ],
    ),
  );

  Widget _heading(ReaderItem it, AppState app, Palette p) {
    final sec = book.sections[it.section];
    final title = app.showNiqqud ? sec.title : stripNiqqud(sec.title);
    final k = app.fontSize / 22;
    if (sec.level == 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 34, bottom: 14),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: textFont,
                fontSize: 30 * k,
                fontWeight: FontWeight.w700,
                color: p.accent,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            _ornament(p, 120),
          ],
        ),
      );
    }
    if (sec.level == 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: textFont,
            fontSize: 24 * k,
            fontWeight: FontWeight.w700,
            color: p.accent,
            height: 1.3,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: textFont,
          fontSize: 20 * k,
          fontWeight: FontWeight.w700,
          color: p.ink,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _paragraph(
    ReaderItem it,
    AppState app,
    Palette p,
    TextStyle style,
    RegExp? re,
    bool focused,
  ) {
    final raw = book.sections[it.section].paragraphs[it.para];
    final text = app.showNiqqud ? raw : stripNiqqud(raw);
    final loc = Loc(it.section, it.para);
    final marked = app.isBookmarked(book.meta.id, loc);
    final notes = app.notesAt(book.meta.id, loc);
    final quoteRe = re == null && notes.any((n) => n.quote.isNotEmpty)
        ? highlightRegex([
            for (final n in notes)
              if (n.quote.isNotEmpty) normalizeForSearch(n.quote),
          ])
        : null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          decoration: focused
              ? BoxDecoration(
                  color: p.mark.withValues(alpha: 0.25),
                  border: BorderDirectional(
                    start: BorderSide(color: p.gold, width: 3),
                  ),
                )
              : null,
          padding: focused
              ? const EdgeInsetsDirectional.only(start: 8)
              : EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text.rich(
                quoteRe != null
                    ? highlightSpan(
                        text,
                        quoteRe,
                        style,
                        p.noteBorder.withValues(alpha: 0.32),
                      )
                    : highlightSpan(text, re, style, p.mark),
                textAlign: app.justify ? TextAlign.justify : TextAlign.start,
              ),
              for (final n in notes)
                NoteBox(
                  note: n,
                  fontSize: app.fontSize,
                  onEdit: () => showNoteEditor(context, book, loc, note: n),
                ),
            ],
          ),
        ),
        // Paragraph number in the page margin; click for actions.
        PositionedDirectional(
          start: _compact(context) ? -30 : -46,
          top: 5 + app.fontSize * 0.35,
          width: _compact(context) ? 26 : 36,
          child: SelectionContainer.disabled(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTapDown: (d) => _paragraphMenu(it, d.globalPosition),
                child: Tooltip(
                  message: 'פעולות על הפסקה',
                  waitDuration: const Duration(milliseconds: 800),
                  child: marked
                      ? Icon(Icons.bookmark, size: 16, color: p.gold)
                      : notes.isNotEmpty
                      ? Icon(
                          Icons.sticky_note_2_outlined,
                          size: 16,
                          color: p.noteBorder,
                        )
                      : Text(
                          hebNum(it.para + 1),
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11.5, color: p.muted),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
