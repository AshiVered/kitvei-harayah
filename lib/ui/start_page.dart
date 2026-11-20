import 'package:material_ui/material_ui.dart';

import '../data/hebrew.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'workspace.dart';

/// דף הבית: כותרת, המשך לימוד, וכל הספרים לפי נושאים.
class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final ws = WorkspaceScope.read(context);
    final p = context.pal;
    final recent = app.recent.take(6).toList();
    return Container(
      color: p.window,
      child: ListView(padding: const EdgeInsets.symmetric(vertical: 36), children: [
        _centered(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('כתבי הראי״ה',
              style: TextStyle(fontFamily: textFont, fontSize: 44, fontWeight: FontWeight.w800, color: p.accent, height: 1.1)),
          const SizedBox(height: 4),
          Text('ספרי מרן הרב אברהם יצחק הכהן קוק זצ״ל',
              style: TextStyle(fontFamily: textFont, fontSize: 19, color: p.muted)),
          const SizedBox(height: 14),
          Row(children: [
            Container(width: 60, height: 2, color: p.gold),
            const SizedBox(width: 12),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: ws.focusSearch,
              icon: const Icon(Icons.search, size: 18),
              label: const Text('חיפוש בכל הספרים  (Ctrl+K)'),
            ),
          ]),
        ])),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 30),
          _centered(_SectionTitle('המשך לימוד')),
          _centered(_Box(children: [
            for (final r in recent) _RecentRow(r),
          ])),
        ],
        const SizedBox(height: 30),
        _centered(_SectionTitle('הספרייה')),
        _centered(LayoutBuilder(builder: (context, cons) {
          final cols = cons.maxWidth > 760 ? 3 : (cons.maxWidth > 480 ? 2 : 1);
          // Balanced columns: each card goes to the currently shortest column, so cards of
          // different heights (10 books vs. 1) don't leave gaps the way fixed rows do.
          final columns = List.generate(cols, (_) => <Widget>[]);
          final heights = List.filled(cols, 0.0);
          for (final c in app.library.categories) {
            final books = app.library.books.where((b) => b.category == c).toList();
            var target = 0;
            for (var i = 1; i < cols; i++) {
              if (heights[i] < heights[target] - 0.5) target = i;
            }
            if (columns[target].isNotEmpty) columns[target].add(const SizedBox(height: 14));
            columns[target].add(_CategoryCard(category: c, books: books));
            heights[target] += 2.2 + books.length; // header ≈ 2 rows, then one row per book
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < cols; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: columns[i])),
            ],
          ]);
        })),
      ]),
    );
  }

  static Widget _centered(Widget child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.ink)),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return Container(
      decoration: BoxDecoration(color: p.page, border: Border.all(color: p.border), borderRadius: BorderRadius.circular(6)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(),
          children[i],
        ],
      ]),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow(this.r);

  final LastRead r;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = context.pal;
    final m = app.library.byId[r.bookId]!;
    final book = app.library.cached(m.id);
    final where = book != null && r.loc.section < book.sections.length
        ? book.breadcrumb(r.loc.section).map(stripNiqqud).join(' › ')
        : m.category;
    return InkWell(
      onTap: () => WorkspaceScope.read(context).openBook(m.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Icon(Icons.menu_book_outlined, size: 18, color: p.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(where, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.muted)),
            ]),
          ),
          SizedBox(
            width: 120,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(value: r.progress.clamp(0.0, 1.0), minHeight: 4, color: p.gold, backgroundColor: p.border),
            ),
          ),
          SizedBox(width: 44, child: Text('${(r.progress * 100).round()}%', textAlign: TextAlign.end, style: TextStyle(fontSize: 12, color: p.muted))),
        ]),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.books});

  final String category;
  final List<BookMeta> books;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final ws = WorkspaceScope.read(context);
    return Container(
      decoration: BoxDecoration(color: p.page, border: Border.all(color: p.border), borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
          child: Row(children: [
            Icon(categoryIcon(category), size: 18, color: p.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(category, style: TextStyle(fontFamily: textFont, fontSize: 17, fontWeight: FontWeight.w700, color: p.accent)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (final b in books) _BookLink(title: b.title, onTap: () => ws.openBook(b.id)),
          ]),
        ),
      ]),
    );
  }
}

class _BookLink extends StatefulWidget {
  const _BookLink({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  State<_BookLink> createState() => _BookLinkState();
}

class _BookLinkState extends State<_BookLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: _hover ? p.selection : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          child: Row(children: [
            Text('›', style: TextStyle(color: p.gold, fontSize: 14)),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.title, style: TextStyle(fontSize: 14, color: _hover ? p.accent : p.ink))),
          ]),
        ),
      ),
    );
  }
}
