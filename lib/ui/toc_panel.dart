import 'package:material_ui/material_ui.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../data/hebrew.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'tree_row.dart';
import 'workspace.dart';

/// תוכן העניינים של הספר הפעיל.
class TocPanelHost extends StatelessWidget {
  const TocPanelHost({super.key});

  @override
  Widget build(BuildContext context) {
    final r = WorkspaceScope.of(context).activeReader;
    if (r == null) {
      return const EmptyState(icon: Icons.format_list_bulleted, title: 'אין ספר פתוח', subtitle: 'פתחו ספר מהספרייה.');
    }
    return TocTree(key: ValueKey(r.book.meta.id), controller: r);
  }
}

class TocTree extends StatefulWidget {
  const TocTree({super.key, required this.controller});

  final ReaderController controller;

  @override
  State<TocTree> createState() => _TocTreeState();
}

class _TocTreeState extends State<TocTree> {
  final Set<int> _expanded = {};
  final _filter = TextEditingController();
  late final List<int> _titled;
  late final List<bool> _hasChildren;
  final _scroll = ItemScrollController();
  int _lastAuto = -1;

  Book get book => widget.controller.book;

  @override
  void initState() {
    super.initState();
    _titled = [for (var i = 0; i < book.sections.length; i++) if (book.sections[i].title.isNotEmpty) i];
    _hasChildren = List.filled(book.sections.length, false);
    for (var k = 0; k < _titled.length - 1; k++) {
      if (book.sections[_titled[k + 1]].level > book.sections[_titled[k]].level) _hasChildren[_titled[k]] = true;
    }
    if (_titled.length <= 80) _expanded.addAll(_titled);
    _expandAncestors(widget.controller.loc.section);
    widget.controller.addListener(_onMove);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onMove);
    _filter.dispose();
    super.dispose();
  }

  void _onMove() => setState(() {});

  void _expandAncestors(int s) {
    var level = 1 << 30;
    for (var i = s; i >= 0; i--) {
      final sec = book.sections[i];
      if (sec.title.isNotEmpty && sec.level < level) {
        _expanded.add(i);
        level = sec.level;
        if (level == 0) break;
      }
    }
  }

  List<int> _visible() {
    final q = normalizeForSearch(_filter.text.trim());
    if (q.isNotEmpty) return _titled.where((i) => normalizeForSearch(book.sections[i].title).contains(q)).toList();
    final out = <int>[];
    var hideBelow = 1 << 30;
    for (final i in _titled) {
      final lvl = book.sections[i].level;
      if (lvl > hideBelow) continue;
      hideBelow = 1 << 30;
      out.add(i);
      if (_hasChildren[i] && !_expanded.contains(i)) hideBelow = lvl;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cur = widget.controller.loc.section;
    var current = -1;
    for (final i in _titled) {
      if (i > cur) break;
      current = i;
    }
    var follow = false;
    if (current != _lastAuto && current >= 0) {
      _lastAuto = current;
      _expandAncestors(current);
      follow = true;
    }
    final visible = _visible();
    final vi = visible.indexOf(current);
    if (follow && vi >= 0 && _filter.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.isAttached) _scroll.jumpTo(index: (vi - 6).clamp(0, visible.length - 1));
      });
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
        child: Text(book.meta.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ),
      if (_titled.length > 12)
        PanelFilter(controller: _filter, hint: 'סינון פרקים', onChanged: (_) => setState(() {})),
      Expanded(
        child: visible.isEmpty
            ? const EmptyState(icon: Icons.format_list_bulleted, title: 'אין פרקים')
            : ScrollablePositionedList.builder(
                itemScrollController: _scroll,
                itemCount: visible.length,
                padding: const EdgeInsets.only(bottom: 12),
                itemBuilder: (context, k) {
                  final i = visible[k];
                  final sec = book.sections[i];
                  final kids = _hasChildren[i] && _filter.text.isEmpty;
                  final open = _expanded.contains(i);
                  return TreeRow(
                    label: stripNiqqud(sec.title),
                    depth: sec.level.clamp(0, 6),
                    expanded: kids ? open : null,
                    bold: sec.level == 0,
                    selected: i == current,
                    maxLines: 2,
                    onToggle: kids ? () => setState(() => open ? _expanded.remove(i) : _expanded.add(i)) : null,
                    onTap: () => widget.controller.jumpTo(Loc(i, -1)),
                  );
                },
              ),
      ),
    ]);
  }
}
