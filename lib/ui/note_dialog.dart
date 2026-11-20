import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../data/hebrew.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Opens the note editor: edits [note] if given, otherwise creates a new note on [loc]
/// (optionally attached to the selected [quote]).
Future<void> showNoteEditor(
  BuildContext context,
  Book book,
  Loc loc, {
  Note? note,
  String quote = '',
}) => showDialog<void>(
  context: context,
  builder: (_) => _NoteDialog(book: book, loc: loc, note: note, quote: quote),
);

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({
    required this.book,
    required this.loc,
    this.note,
    this.quote = '',
  });

  final Book book;
  final Loc loc;
  final Note? note;
  final String quote;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _ctl = TextEditingController(
    text: widget.note?.text ?? '',
  );

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  String get _quote => widget.note?.quote ?? widget.quote;

  void _save() {
    final app = AppScope.read(context);
    if (widget.note != null) {
      app.updateNote(widget.note!, _ctl.text);
    } else if (_ctl.text.trim().isNotEmpty) {
      app.addNote(widget.book, widget.loc, _ctl.text, quote: widget.quote);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final app = AppScope.of(context);
    final para =
        widget.book.sections[widget.loc.section].paragraphs[widget.loc.para];
    final shown = stripNiqqud(_quote.isNotEmpty ? _quote : para);
    final excerpt = shown.length > 220 ? '${shown.substring(0, 220)}…' : shown;
    final where = [
      widget.book.meta.title,
      ...widget.book.breadcrumb(widget.loc.section).map(stripNiqqud),
    ].join(' › ');
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _save,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
      },
      child: Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_outlined, color: p.noteBorder),
                    const SizedBox(width: 8),
                    Text(
                      widget.note == null ? 'הערה חדשה' : 'עריכת הערה',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(where, style: TextStyle(fontSize: 12, color: p.muted)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: p.page,
                    border: BorderDirectional(
                      start: BorderSide(color: p.noteBorder, width: 3),
                    ),
                  ),
                  child: Text(
                    _quote.isNotEmpty ? '„$excerpt”' : excerpt,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: app.font.family,
                      fontSize: 14.5,
                      height: 1.4,
                      color: p.muted,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Focus(
                  canRequestFocus: false,
                  skipTraversal: true,
                  // Ctrl+Enter saves even while typing (the text field would otherwise take the key).
                  onKeyEvent: (node, e) {
                    if (e is KeyDownEvent &&
                        (e.logicalKey == LogicalKeyboardKey.enter ||
                            e.logicalKey == LogicalKeyboardKey.numpadEnter) &&
                        HardwareKeyboard.instance.isControlPressed) {
                      _save();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _ctl,
                    autofocus: true,
                    minLines: 5,
                    maxLines: 12,
                    style: TextStyle(
                      fontFamily: uiFont,
                      fontSize: 15,
                      height: 1.45,
                      color: p.noteInk,
                    ),
                    decoration: InputDecoration(
                      hintText: 'כתבו כאן את ההערה שלכם…',
                      fillColor: p.note,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: p.noteBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: p.noteBorder, width: 1.6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (widget.note != null)
                      TextButton.icon(
                        onPressed: () {
                          AppScope.read(context).removeNote(widget.note!);
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('מחיקת ההערה'),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('ביטול'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _save,
                      child: const Text('שמירה (Ctrl+Enter)'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A note as shown under its paragraph: a different font, colour and background.
class NoteBox extends StatelessWidget {
  const NoteBox({
    super.key,
    required this.note,
    required this.onEdit,
    required this.fontSize,
  });

  final Note note;
  final VoidCallback onEdit;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final p = context.pal;
    final q = stripNiqqud(note.quote);
    return SelectionContainer.disabled(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onEdit,
          child: Container(
            margin: const EdgeInsets.only(top: 4, bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(
              color: p.note,
              borderRadius: BorderRadius.circular(4),
              border: BorderDirectional(
                start: BorderSide(color: p.noteBorder, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 14, color: p.noteBorder),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        q.isEmpty
                            ? 'ההערה שלי'
                            : 'ההערה שלי על „${q.length > 60 ? '${q.substring(0, 60)}…' : q}”',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: uiFont,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: p.noteBorder,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  note.text,
                  style: TextStyle(
                    fontFamily: uiFont,
                    fontStyle: FontStyle.italic,
                    fontSize: (fontSize * 0.72).clamp(13, 22),
                    height: 1.45,
                    color: p.noteInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
