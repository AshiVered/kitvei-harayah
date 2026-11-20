import 'package:material_ui/material_ui.dart';

import '../data/hebrew.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'tree_row.dart';
import 'workspace.dart';

/// עץ הספרייה: נושאים ← ספרים.
class LibraryPanel extends StatefulWidget {
  const LibraryPanel({super.key});

  @override
  State<LibraryPanel> createState() => _LibraryPanelState();
}

class _LibraryPanelState extends State<LibraryPanel> {
  final _filter = TextEditingController();
  final Set<String> _collapsed = {};

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final ws = WorkspaceScope.of(context);
    final q = normalizeForSearch(_filter.text.trim());
    final activeId = ws.activeReader?.book.meta.id;
    final rows = <Widget>[];
    for (final c in app.library.categories) {
      final books = app.library.books
          .where((b) => b.category == c && (q.isEmpty || normalizeForSearch(b.title).contains(q)))
          .toList();
      if (books.isEmpty) continue;
      final open = q.isNotEmpty || !_collapsed.contains(c);
      rows.add(TreeRow(
        label: c,
        icon: categoryIcon(c),
        bold: true,
        expanded: open,
        onToggle: () => setState(() => open ? _collapsed.add(c) : _collapsed.remove(c)),
      ));
      if (open) {
        for (final b in books) {
          final h = app.history[b.id];
          rows.add(TreeRow(
            label: b.title,
            depth: 1,
            icon: Icons.menu_book_outlined,
            selected: b.id == activeId,
            trailing: h == null ? null : '${(h.progress * 100).round()}%',
            onTap: () => ws.openBook(b.id),
          ));
        }
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PanelFilter(controller: _filter, hint: 'סינון ספרים', onChanged: (_) => setState(() {})),
      Expanded(child: ListView(padding: const EdgeInsets.only(bottom: 12), children: rows)),
    ]);
  }
}
