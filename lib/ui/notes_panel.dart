import 'package:material_ui/material_ui.dart';

import '../data/hebrew.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'workspace.dart';

/// כל ההערות האישיות של המשתמש.
class NotesPanel extends StatelessWidget {
  const NotesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final ws = WorkspaceScope.read(context);
    final p = context.pal;
    if (!app.personalData) {
      return const EmptyState(
        icon: Icons.desktop_windows_outlined,
        title: 'הערות נתמכות רק בגרסת התוכנה למחשב',
        subtitle: 'בגרסת האתר לא נשמר מידע אישי.',
      );
    }
    if (app.notes.isEmpty) {
      return const EmptyState(
        icon: Icons.sticky_note_2_outlined,
        title: 'אין הערות',
        subtitle: 'סמנו טקסט בספר, לחצו קליק ימני ובחרו „הוספת הערה”.',
      );
    }
    final notes = [...app.notes]..sort((a, b) => b.updated.compareTo(a.updated));
    return ListView.separated(
      itemCount: notes.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, i) {
        final n = notes[i];
        final m = app.library.byId[n.bookId]!;
        return InkWell(
          onTap: () => ws.openBook(n.bookId, at: n.loc),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(Icons.sticky_note_2_outlined, size: 16, color: p.noteBorder),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text([m.title, if (n.label.isNotEmpty) stripNiqqud(n.label)].join(' › '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.accent)),
                  const SizedBox(height: 2),
                  Text(n.text,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: uiFont, fontStyle: FontStyle.italic, fontSize: 13.5, height: 1.4)),
                ]),
              ),
              IconButton(
                tooltip: 'מחיקה',
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, color: p.muted),
                onPressed: () => app.removeNote(n),
              ),
            ]),
          ),
        );
      },
    );
  }
}
