import 'package:material_ui/material_ui.dart';

import '../data/hebrew.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'workspace.dart';

class BookmarksPanel extends StatelessWidget {
  const BookmarksPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final ws = WorkspaceScope.read(context);
    final p = context.pal;
    if (!app.personalData) {
      return const EmptyState(
        icon: Icons.desktop_windows_outlined,
        title: 'סימניות נתמכות רק בגרסת התוכנה למחשב',
        subtitle: 'בגרסת האתר לא נשמר מידע אישי.',
      );
    }
    if (app.bookmarks.isEmpty) {
      return const EmptyState(
        icon: Icons.bookmark_border,
        title: 'אין סימניות',
        subtitle: 'לחצו על מספר פסקה בשולי הטקסט, או על כפתור הסימנייה בסרגל הקריאה.',
      );
    }
    return ListView.separated(
      itemCount: app.bookmarks.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (context, i) {
        final b = app.bookmarks[i];
        final m = app.library.byId[b.bookId]!;
        return InkWell(
          onTap: () => ws.openBook(b.bookId, at: b.loc),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 1), child: Icon(Icons.bookmark, size: 16, color: p.gold)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text([m.title, if (b.label.isNotEmpty) stripNiqqud(b.label)].join(' › '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.accent)),
                  const SizedBox(height: 2),
                  Text(app.showNiqqud ? b.snippet : stripNiqqud(b.snippet),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: app.font.family, fontSize: 14, height: 1.4)),
                ]),
              ),
              IconButton(
                tooltip: 'מחיקה',
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, color: p.muted),
                onPressed: () => app.removeBookmark(b),
              ),
            ]),
          ),
        );
      },
    );
  }
}
