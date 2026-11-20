import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// A compact, desktop-style row for trees and lists in side panels.
class TreeRow extends StatefulWidget {
  const TreeRow({
    super.key,
    required this.label,
    this.depth = 0,
    this.icon,
    this.expanded,
    this.onToggle,
    this.onTap,
    this.selected = false,
    this.trailing,
    this.bold = false,
    this.maxLines = 1,
  });

  final String label;
  final int depth;
  final IconData? icon;
  final bool? expanded; // null = leaf
  final VoidCallback? onToggle;
  final VoidCallback? onTap;
  final bool selected;
  final String? trailing;
  final bool bold;
  final int maxLines;

  @override
  State<TreeRow> createState() => _TreeRowState();
}

class _TreeRowState extends State<TreeRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final bg = widget.selected ? p.selection : (_hover ? p.ink.withValues(alpha: 0.05) : null);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap ?? widget.onToggle,
        child: Container(
          constraints: const BoxConstraints(minHeight: 28),
          color: bg,
          padding: EdgeInsetsDirectional.only(start: 6.0 + 14.0 * widget.depth, end: 10, top: 3, bottom: 3),
          child: Row(children: [
            SizedBox(
              width: 18,
              child: widget.expanded == null
                  ? null
                  : GestureDetector(
                      onTap: widget.onToggle,
                      child: Icon(widget.expanded! ? Icons.expand_more : Icons.chevron_right, size: 16, color: p.muted),
                    ),
            ),
            if (widget.icon != null) ...[
              const SizedBox(width: 2),
              Icon(widget.icon, size: 16, color: widget.selected ? p.accent : p.muted),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                widget.label,
                maxLines: widget.maxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  color: widget.selected ? p.accent : p.ink,
                  fontWeight: widget.bold || widget.selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (widget.trailing != null)
              Text(widget.trailing!, style: TextStyle(fontSize: 11.5, color: p.muted)),
          ]),
        ),
      ),
    );
  }
}

/// A filter field shown at the top of side panels.
class PanelFilter extends StatelessWidget {
  const PanelFilter({super.key, required this.controller, required this.hint, this.onChanged, this.focusNode, this.onSubmitted});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: const TextStyle(fontSize: 13.5),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 34),
        ),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
  }
}
