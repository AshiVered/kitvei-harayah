/// Hebrew text helpers: niqqud stripping, search normalization, highlighting.
library;

final RegExp _marks = RegExp('[֑-ֽֿ-ׇ]');
final RegExp _quotes = RegExp('["\'׳״“”‘’]');
final RegExp _spaces = RegExp(r'\s+');

/// Removes vowel points (niqqud) and cantillation marks, keeping letters.
String stripNiqqud(String s) => s.replaceAll(_marks, '').replaceAll('־', '-');

/// Normalization used for the search index: no niqqud, no quotes/gershayim,
/// maqaf as space, collapsed whitespace.
String normalizeForSearch(String s) {
  return s
      .replaceAll('־', ' ')
      .replaceAll(_marks, '')
      .replaceAll(_quotes, '')
      .replaceAll(_spaces, ' ');
}

/// Splits a user query into terms. Text in double quotes is kept as a phrase.
List<String> queryTerms(String query) {
  final terms = <String>[];
  final phrase = RegExp(r'"([^"]+)"|(\S+)');
  for (final m in phrase.allMatches(query)) {
    final t = normalizeForSearch(m.group(1) ?? m.group(2) ?? '').trim();
    if (t.isNotEmpty) terms.add(t);
  }
  return terms;
}

/// A regex that matches [term] inside original (vocalized, punctuated) text.
RegExp highlightRegex(List<String> terms) {
  String one(String term) {
    final buf = StringBuffer();
    for (final rune in term.runes) {
      final ch = String.fromCharCode(rune);
      if (ch == ' ') {
        buf.write('[\\s־]+');
      } else {
        buf.write(RegExp.escape(ch));
      }
      buf.write('[֑-ׇ"\'׳״]*');
    }
    return buf.toString();
  }

  final pattern = terms.where((t) => t.isNotEmpty).map(one).join('|');
  return RegExp(pattern.isEmpty ? r'(?!)' : pattern);
}

const _ones = ['', 'א', 'ב', 'ג', 'ד', 'ה', 'ו', 'ז', 'ח', 'ט'];
const _tens = ['', 'י', 'כ', 'ל', 'מ', 'נ', 'ס', 'ע', 'פ', 'צ'];
const _hundreds = ['', 'ק', 'ר', 'ש', 'ת'];

/// Hebrew numeral, e.g. 15 → ט״ו.
String hebNum(int n) {
  if (n <= 0) return '$n';
  var out = '';
  var x = n % 1000;
  while (x >= 400) {
    out += 'ת';
    x -= 400;
  }
  out += _hundreds[x ~/ 100];
  x %= 100;
  if (x == 15) {
    out += 'טו';
  } else if (x == 16) {
    out += 'טז';
  } else {
    out += _tens[x ~/ 10] + _ones[x % 10];
  }
  if (out.length == 1) return '$out׳';
  return '${out.substring(0, out.length - 1)}״${out.substring(out.length - 1)}';
}

/// Formats a number with thousands separators.
String fmtNum(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}
