import 'package:material_ui/material_ui.dart';

import '../data/hebrew.dart';
import '../data/library.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'tree_row.dart';
import 'workspace.dart';

/// חיפוש מלא בכל הספרים, ללא תלות בניקוד.
class SearchPanel extends StatefulWidget {
  const SearchPanel({super.key});

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  final _ctl = TextEditingController();
  SearchResult? _result;
  bool _busy = false;
  String? _category;
  String? _bookFilter;
  RegExp? _re;
  int _seq = 0;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final q = _ctl.text.trim();
    if (q.isEmpty) return;
    final app = AppScope.read(context);
    final seq = ++_seq;
    setState(() {
      _busy = true;
      _bookFilter = null;
    });
    final scope = _category == null
        ? null
        : app.library.books.where((b) => b.category == _category).map((b) => b.id).toSet();
    final res = await app.search.search(q, bookIds: scope);
    if (!mounted || seq != _seq) return;
    setState(() {
      _busy = false;
      _result = res;
      _re = highlightRegex(res.terms);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final ws = WorkspaceScope.of(context);
    final p = context.pal;
    final res = _result;
    final hits = res == null
        ? const <SearchHit>[]
        : (_bookFilter == null ? res.hits : res.hits.where((h) => h.book.meta.id == _bookFilter).toList());
    final small = TextStyle(fontSize: 12.5, color: p.muted);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PanelFilter(
        controller: _ctl,
        focusNode: ws.searchFocus,
        hint: 'חיפוש בכל הספרים…',
        onSubmitted: (_) => _run(),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
        child: Row(children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _category,
                isExpanded: true,
                isDense: true,
                style: TextStyle(fontSize: 13, color: p.ink, fontFamily: uiFont),
                items: [
                  const DropdownMenuItem(value: null, child: Text('כל הנושאים')),
                  for (final c in app.library.categories) DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) {
                  setState(() => _category = v);
                  if (_ctl.text.trim().isNotEmpty) _run();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
            onPressed: _busy ? null : _run,
            child: const Text('חיפוש'),
          ),
        ]),
      ),
      if (_busy)
        ValueListenableBuilder<double>(
          valueListenable: app.search.progress,
          builder: (_, v, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LinearProgressIndicator(value: app.search.ready ? null : v, minHeight: 2),
              if (!app.search.ready) Padding(padding: const EdgeInsets.only(top: 4), child: Text('מכין את מאגר החיפוש…', style: small)),
            ]),
          ),
        ),
      if (res != null && !_busy) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
          child: Text(
            '${fmtNum(res.perBook.values.fold(0, (a, b) => a + b))} תוצאות ב־${res.perBook.length} ספרים'
            '${res.truncated ? ' (מוצגות ${fmtNum(res.hits.length)})' : ''}',
            style: small,
          ),
        ),
        if (res.perBook.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _bookFilter,
                isExpanded: true,
                isDense: true,
                style: TextStyle(fontSize: 13, color: p.ink, fontFamily: uiFont),
                items: [
                  const DropdownMenuItem(value: null, child: Text('כל הספרים')),
                  for (final e in (res.perBook.entries.toList()..sort((a, b) => b.value.compareTo(a.value))))
                    DropdownMenuItem(value: e.key, child: Text('${app.library.byId[e.key]!.title} (${e.value})')),
                ],
                onChanged: (v) => setState(() => _bookFilter = v),
              ),
            ),
          ),
      ],
      const Divider(),
      Expanded(
        child: res == null
            ? const EmptyState(
                icon: Icons.manage_search,
                title: 'חיפוש בכל כתבי הראי״ה',
                subtitle: 'ללא תלות בניקוד ובגרשיים.\nכמה מילים – פסקאות שבהן מופיעות כולן.\nצירוף מדויק – בין מירכאות.',
              )
            : hits.isEmpty
                ? const EmptyState(icon: Icons.search_off, title: 'לא נמצאו תוצאות')
                : ListView.separated(
                    itemCount: hits.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, i) => _Hit(hit: hits[i], re: _re!, query: _ctl.text),
                  ),
      ),
    ]);
  }
}

class _Hit extends StatefulWidget {
  const _Hit({required this.hit, required this.re, required this.query});

  final SearchHit hit;
  final RegExp re;
  final String query;

  @override
  State<_Hit> createState() => _HitState();
}

class _HitState extends State<_Hit> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = context.pal;
    final b = widget.hit.book;
    final raw = b.sections[widget.hit.section].paragraphs[widget.hit.para];
    final text = app.showNiqqud ? raw : stripNiqqud(raw);
    final crumbs = [b.meta.title, ...b.breadcrumb(widget.hit.section).map(stripNiqqud)].join(' › ');
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => WorkspaceScope.read(context)
            .openBook(b.meta.id, at: Loc(widget.hit.section, widget.hit.para), highlight: widget.query),
        child: Container(
          color: _hover ? p.ink.withValues(alpha: 0.05) : null,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(crumbs,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.accent)),
            const SizedBox(height: 3),
            Text.rich(
              highlightSpan(snippetAround(text, widget.re, radius: 90), widget.re,
                  TextStyle(fontFamily: app.font.family, fontSize: 14.5, height: 1.45, color: p.ink), p.mark),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
      ),
    );
  }
}
