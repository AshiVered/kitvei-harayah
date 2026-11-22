import 'package:flutter/gestures.dart' show kMiddleMouseButton;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../data/hebrew.dart';
import '../platform/platform.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'about_view.dart';
import 'bookmarks_panel.dart';
import 'library_panel.dart';
import 'notes_panel.dart';
import 'reader_view.dart';
import 'search_panel.dart';
import 'settings_dialog.dart';
import 'start_page.dart';
import 'toc_panel.dart';
import 'workspace.dart';

class MainWindow extends StatefulWidget {
  const MainWindow({super.key});

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  late final Workspace ws = Workspace(AppScope.read(context));

  @override
  void initState() {
    super.initState();
    // Dev hook for screenshots/testing: KITVEI_OPEN=<bookId>, KITVEI_PANEL=toc|search|bookmarks.
    final open = envVar('KITVEI_OPEN');
    final panel = envVar('KITVEI_PANEL');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (panel != null) ws.showPanel(SidePanel.values.firstWhere((p) => p.name == panel, orElse: () => ws.panel));
      if (open != null) ws.openBook(open);
    });
  }

  @override
  void dispose() {
    ws.dispose();
    super.dispose();
  }

  bool _firstLayout = true;

  /// Phones and narrow windows get the compact layout (bottom bar, full-screen panels).
  bool _isCompact(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < compactBreakpoint;
    ws.compact = compact;
    if (_firstLayout) {
      _firstLayout = false;
      if (compact) ws.panelOpen = false; // open on the home page, not on a full-screen panel
    }
    return compact;
  }

  @override
  Widget build(BuildContext context) {
    return WorkspaceScope(
      ws: ws,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyW, control: true): () => ws.close(ws.active),
          const SingleActivator(LogicalKeyboardKey.tab, control: true): () => ws.cycle(1),
          const SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true): () => ws.cycle(-1),
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): ws.focusSearch,
          const SingleActivator(LogicalKeyboardKey.keyB, control: true): () => ws.showPanel(ws.panel),
          const SingleActivator(LogicalKeyboardKey.comma, control: true): () => showSettingsDialog(context),
        },
        child: Focus(
          autofocus: true,
          child: ListenableBuilder(
            listenable: ws,
            builder: (context, _) => _isCompact(context) ? const _CompactLayout() : Scaffold(
              body: Column(children: [
                Expanded(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const _ActivityBar(),
                    if (ws.panelOpen) ...[
                      SizedBox(width: ws.panelWidth, child: const _SidePanelHost()),
                      _Splitter(onDrag: (dx) => ws.setPanelWidth(ws.panelWidth - dx)),
                    ],
                    const Expanded(child: _DocumentArea()),
                  ]),
                ),
                const _StatusBar(),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- compact layout (phones)

const compactBreakpoint = 720.0;

class _CompactLayout extends StatelessWidget {
  const _CompactLayout();

  static const _panels = [
    (SidePanel.library, Icons.local_library_outlined, 'ספרייה'),
    (SidePanel.toc, Icons.format_list_bulleted, 'תוכן'),
    (SidePanel.search, Icons.search, 'חיפוש'),
    (SidePanel.bookmarks, Icons.bookmarks_outlined, 'סימניות'),
    (SidePanel.notes, Icons.sticky_note_2_outlined, 'הערות'),
  ];

  @override
  Widget build(BuildContext context) {
    final ws = WorkspaceScope.of(context);
    final p = context.pal;
    final title = ws.panelOpen
        ? _panels.firstWhere((x) => x.$1 == ws.panel).$3
        : ws.activeTab.title;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // top bar
          Container(
            height: 48,
            color: p.activity,
            padding: const EdgeInsetsDirectional.only(start: 6, end: 2),
            child: Row(children: [
              if (ws.panelOpen)
                IconButton(
                  tooltip: 'סגירה',
                  icon: Icon(Icons.close, color: p.onActivity),
                  onPressed: () => ws.showPanel(ws.panel),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Image.asset('assets/icon/icon.png', width: 30, height: 30, filterQuality: FilterQuality.medium),
                ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: textFont, fontSize: 18, fontWeight: FontWeight.w700, color: p.gold)),
              ),
              PopupMenuButton<String>(
                tooltip: 'תפריט',
                icon: Icon(Icons.more_vert, color: p.onActivity),
                onSelected: (v) {
                  switch (v) {
                    case 'home':
                      ws.openStart();
                    case 'about':
                      ws.openAbout();
                    case 'settings':
                      showSettingsDialog(context);
                    default:
                      if (v.startsWith('tab:')) {
                        ws.activate(int.parse(v.substring(4)));
                        ws.panelOpen = false;
                      } else if (v.startsWith('close:')) {
                        ws.close(int.parse(v.substring(6)));
                      }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'home', child: _MenuRow(Icons.home_outlined, 'דף הבית')),
                  const PopupMenuItem(value: 'settings', child: _MenuRow(Icons.settings_outlined, 'הגדרות')),
                  const PopupMenuItem(value: 'about', child: _MenuRow(Icons.info_outline, 'אודות')),
                  if (ws.tabs.length > 1) ...[
                    const PopupMenuDivider(),
                    for (var i = 0; i < ws.tabs.length; i++)
                      PopupMenuItem(
                        value: 'tab:$i',
                        child: Row(children: [
                          Icon(ws.tabs[i].icon, size: 18, color: i == ws.active ? p.gold : null),
                          const SizedBox(width: 10),
                          Expanded(child: Text(ws.tabs[i].title, overflow: TextOverflow.ellipsis)),
                          IconButton(
                            tooltip: 'סגירה',
                            iconSize: 16,
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              Navigator.pop(context);
                              ws.close(i);
                            },
                          ),
                        ]),
                      ),
                  ],
                ],
              ),
            ]),
          ),
          // content: the open document, with a panel over it when one is open
          Expanded(
            child: Stack(children: [
              const Positioned.fill(child: _DocumentArea(showTabs: false)),
              if (ws.panelOpen)
                Positioned.fill(
                  child: ColoredBox(
                    color: p.panel,
                    child: IndexedStack(
                      index: SidePanel.values.indexOf(ws.panel),
                      children: const [LibraryPanel(), TocPanelHost(), SearchPanel(), BookmarksPanel(), NotesPanel()],
                    ),
                  ),
                ),
            ]),
          ),
          // bottom navigation
          Container(
            decoration: BoxDecoration(color: p.activity, border: Border(top: BorderSide(color: p.border))),
            child: Row(children: [
              for (final (panel, icon, label) in _panels)
                Expanded(
                  child: InkWell(
                    onTap: () => ws.showPanel(panel),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icon,
                            size: 22,
                            color: ws.panelOpen && ws.panel == panel ? p.gold : p.onActivity.withValues(alpha: 0.7)),
                        const SizedBox(height: 2),
                        Text(label,
                            style: TextStyle(
                                fontSize: 11,
                                color: ws.panelOpen && ws.panel == panel ? p.gold : p.onActivity.withValues(alpha: 0.7))),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Row(children: [Icon(icon, size: 18), const SizedBox(width: 10), Text(label)]);
}

// ---------------------------------------------------------------- activity bar

class _ActivityBar extends StatelessWidget {
  const _ActivityBar();

  @override
  Widget build(BuildContext context) {
    final ws = WorkspaceScope.of(context);
    final p = context.pal;
    Widget item(IconData icon, String tip, SidePanel panel) =>
        _ActivityButton(icon: icon, tooltip: tip, active: ws.panelOpen && ws.panel == panel, onTap: () => ws.showPanel(panel));
    return Container(
      width: 52,
      color: p.activity,
      child: Column(children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Image.asset('assets/icon/icon.png', width: 36, height: 36, filterQuality: FilterQuality.medium),
        ),
        item(Icons.local_library_outlined, 'ספרייה', SidePanel.library),
        item(Icons.format_list_bulleted, 'תוכן העניינים', SidePanel.toc),
        item(Icons.search, 'חיפוש (Ctrl+K)', SidePanel.search),
        item(Icons.bookmarks_outlined, 'סימניות', SidePanel.bookmarks),
        item(Icons.sticky_note_2_outlined, 'הערות', SidePanel.notes),
        const Spacer(),
        _ActivityButton(icon: Icons.home_outlined, tooltip: 'דף הבית', active: false, onTap: ws.openStart),
        _ActivityButton(icon: Icons.info_outline, tooltip: 'אודות', active: false, onTap: ws.openAbout),
        _ActivityButton(
          icon: Icons.settings_outlined,
          tooltip: 'הגדרות (Ctrl+,)',
          active: false,
          onTap: () => showSettingsDialog(context),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

class _ActivityButton extends StatefulWidget {
  const _ActivityButton({required this.icon, required this.tooltip, required this.active, required this.onTap});

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_ActivityButton> createState() => _ActivityButtonState();
}

class _ActivityButtonState extends State<_ActivityButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final color = widget.active || _hover ? p.onActivity : p.onActivity.withValues(alpha: 0.55);
    return Tooltip(
      message: widget.tooltip,
      preferBelow: false,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              border: BorderDirectional(
                start: BorderSide(color: widget.active ? p.gold : Colors.transparent, width: 2.5),
              ),
            ),
            child: Icon(widget.icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- side panel

class _SidePanelHost extends StatelessWidget {
  const _SidePanelHost();

  @override
  Widget build(BuildContext context) {
    final ws = WorkspaceScope.of(context);
    final p = context.pal;
    final title = switch (ws.panel) {
      SidePanel.library => 'ספרייה',
      SidePanel.toc => 'תוכן העניינים',
      SidePanel.search => 'חיפוש',
      SidePanel.bookmarks => 'סימניות',
      SidePanel.notes => 'הערות',
    };
    return Container(
      color: p.panel,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 38,
          padding: const EdgeInsetsDirectional.only(start: 14, end: 4),
          child: Row(children: [
            Expanded(
              child: Text(title,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.muted, letterSpacing: 0.3)),
            ),
            IconButton(
              tooltip: 'הסתרת הלוח (Ctrl+B)',
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close, color: p.muted),
              onPressed: () => ws.showPanel(ws.panel),
            ),
          ]),
        ),
        Expanded(
          child: IndexedStack(
            index: SidePanel.values.indexOf(ws.panel),
            children: const [LibraryPanel(), TocPanelHost(), SearchPanel(), BookmarksPanel(), NotesPanel()],
          ),
        ),
      ]),
    );
  }
}

class _Splitter extends StatelessWidget {
  const _Splitter({required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // In RTL the panel is on the right: dragging left widens it.
        onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
        child: Container(
          width: 5,
          color: p.panel,
          alignment: Alignment.center,
          child: Container(width: 1, color: p.border),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- documents

class _DocumentArea extends StatelessWidget {
  const _DocumentArea({this.showTabs = true});

  final bool showTabs;

  @override
  Widget build(BuildContext context) {
    final ws = WorkspaceScope.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (showTabs) const _TabStrip(),
      Expanded(
        child: IndexedStack(
          index: ws.active,
          children: [
            for (final t in ws.tabs)
              KeyedSubtree(
                key: ValueKey(t.id),
                child: switch (t.kind) {
                  TabKind.start => const StartPage(),
                  TabKind.about => const AboutView(),
                  TabKind.book => ReaderView(controller: t.reader!),
                },
              ),
          ],
        ),
      ),
    ]);
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip();

  @override
  Widget build(BuildContext context) {
    final ws = WorkspaceScope.of(context);
    final p = context.pal;
    return Container(
      height: 36,
      decoration: BoxDecoration(color: p.window, border: Border(bottom: BorderSide(color: p.border))),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < ws.tabs.length; i++) _TabChip(index: i),
        ],
      ),
    );
  }
}

class _TabChip extends StatefulWidget {
  const _TabChip({required this.index});

  final int index;

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final ws = WorkspaceScope.of(context);
    final p = context.pal;
    final t = ws.tabs[widget.index];
    final active = widget.index == ws.active;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Listener(
        onPointerDown: (e) {
          if (e.buttons == kMiddleMouseButton) ws.close(widget.index);
        },
        child: GestureDetector(
          onTap: () => ws.activate(widget.index),
          child: Container(
            width: 200,
            padding: const EdgeInsetsDirectional.only(start: 12, end: 4),
            decoration: BoxDecoration(
              color: active ? p.page : (_hover ? p.panelAlt : Colors.transparent),
              border: Border(
                top: BorderSide(color: active ? p.gold : Colors.transparent, width: 2),
                left: BorderSide(color: p.border),
              ),
            ),
            child: Row(children: [
              Icon(t.icon, size: 15, color: active ? p.accent : p.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: active ? p.ink : p.muted, fontWeight: active ? FontWeight.w600 : null),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 22,
                height: 22,
                child: (active || _hover)
                    ? IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 14,
                        tooltip: 'סגירה (Ctrl+W)',
                        icon: Icon(Icons.close, color: p.muted),
                        onPressed: () => ws.close(widget.index),
                      )
                    : null,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- status bar

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    final ws = WorkspaceScope.of(context);
    final p = context.pal;
    final r = ws.activeReader;
    final style = TextStyle(fontSize: 12, color: p.onActivity.withValues(alpha: 0.85));
    return Container(
      height: 24,
      color: p.activity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        if (r != null)
          ListenableBuilder(
            listenable: r,
            builder: (_, _) {
              final crumbs = r.book.breadcrumb(r.loc.section).map(stripNiqqud).join(' › ');
              return Expanded(
                child: Text(
                  '${r.book.meta.title}${crumbs.isEmpty ? '' : '  ›  $crumbs'}    ·    ${(r.progress * 100).round()}%',
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          )
        else
          const Spacer(),
      ]),
    );
  }
}
