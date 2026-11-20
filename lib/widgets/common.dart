import 'package:material_ui/material_ui.dart';

/// Text with search-term highlights.
TextSpan highlightSpan(String text, RegExp? re, TextStyle style, Color mark) {
  if (re == null) return TextSpan(text: text, style: style);
  final spans = <TextSpan>[];
  var last = 0;
  for (final m in re.allMatches(text)) {
    if (m.end == m.start) continue;
    if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
    spans.add(TextSpan(text: text.substring(m.start, m.end), style: TextStyle(backgroundColor: mark)));
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return TextSpan(style: style, children: spans);
}

/// A short excerpt of [text] around the first match of [re].
String snippetAround(String text, RegExp re, {int radius = 110}) {
  final m = re.firstMatch(text);
  if (m == null) return text.length > radius * 2 ? '${text.substring(0, radius * 2)}…' : text;
  var start = (m.start - radius).clamp(0, text.length);
  var end = (m.end + radius).clamp(0, text.length);
  while (start > 0 && text[start] != ' ') {
    start--;
  }
  while (end < text.length && text[end] != ' ') {
    end++;
  }
  return '${start > 0 ? '…' : ''}${text.substring(start, end).trim()}${end < text.length ? '…' : ''}';
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: cs.outline),
          const SizedBox(height: 12),
          Text(title, style: t.titleMedium, textAlign: TextAlign.center),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ]),
      ),
    );
  }
}
