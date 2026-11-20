import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../version.dart';

/// אודות: שם התוכנה, גרסה, מפתח, ריפו, רישיון התוכנה, ופרטי הרישיון
/// של כל מהדורת טקסט שמוטמעת בתוכנה.
class AboutView extends StatelessWidget {
  const AboutView({super.key});

  Future<List<Map<String, dynamic>>> _licenses() async =>
      (jsonDecode(await rootBundle.loadString('assets/text_licenses.json')) as List).cast();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    Widget c(Widget w) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: w),
          ),
        );
    return Container(
      color: context.pal.window,
      child: ListView(padding: const EdgeInsets.symmetric(vertical: 24), children: [
        c(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Image.asset('assets/icon/icon.png', width: 112, height: 112)),
            const SizedBox(height: 8),
            Center(child: Text(appName, style: t.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: cs.primary))),
            Center(
              child: Text('ספריית כתבי הרב אברהם יצחק הכהן קוק זצ״ל'),
            ),
            const SizedBox(height: 16),
            Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 0,
                      color: context.pal.page,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: context.pal.border)),
              child: Column(children: [
                const ListTile(leading: Icon(Icons.tag), title: Text('גרסה'), trailing: Text(appVersion)),
                const ListTile(leading: Icon(Icons.person_outline), title: Text('פיתוח'), trailing: Text(appDeveloper)),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('קוד המקור (GitHub)'),
                  subtitle: Text(appRepoUrl.isEmpty ? 'יעודכן בהמשך' : appRepoUrl, textDirection: TextDirection.ltr),
                  onTap: appRepoUrl.isEmpty ? null : () => _open(appRepoUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.gavel),
                  title: const Text('רישיון התוכנה'),
                  subtitle: const Text('$appLicense – חל על קוד התוכנה בלבד'),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('MIT License'),
                      content: SingleChildScrollView(
                        child: Text(mitLicenseText, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 13)),
                      ),
                      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('סגירה'))],
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.extension_outlined),
                  title: const Text('רישיונות ספריות קוד וגופנים'),
                  subtitle: const Text('רכיבי קוד פתוח שהתוכנה בנויה עליהם, והגופנים Frank Ruhl Libre, David Libre ו-Heebo (SIL OFL)'),
                  onTap: () => showLicensePage(context: context, applicationName: appName, applicationVersion: appVersion),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_outlined),
                  title: const Text('דיוקן הרב באייקון'),
                  subtitle: const Text('צילום משנת 1924 (תרפ״ד), אוסף ספריית הקונגרס האמריקנית (npcc.25595) – נחלת הכלל'),
                  onTap: () => _open('https://commons.wikimedia.org/wiki/File:Abraham_Isaac_Kook_1924.jpg'),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Text('הטקסטים', style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text(
              'הטקסטים הדיגיטליים מגיעים מספריא (Sefaria.org) ומוויקיטקסט העברי (he.wikisource.org), '
              'ומוטמעים בתוכנה כך שהיא עובדת בלי אינטרנט. '
              'רישיון ה-MIT של התוכנה לא חל עליהם: כל מהדורה כפופה לרישיון שלה, כמפורט כאן. '
              'טקסטים מוויקיטקסט ברישיון CC BY-SA – מותר להשתמש, לשנות ולהפיץ, עם ייחוס ובאותו רישיון.\n\n'
              'בתוכנה נכללות רק מהדורות שהרישיון שלהן מוצהר במקור. '
              'מהדורות שבספריא לא צוין להן רישיון – לפי ספריא „טרם אומת מעמד זכויות היוצרים שלהן” – לא נכללו, '
              'גם כשהחיבור עצמו ישן: עריכה וליקוט של כתבי הרב בידי אחרים עשויים להיות מוגנים בנפרד. '
              'כאשר ספר קיים בשני המקורות, נבחרה המהדורה השלמה יותר מבין המותרות.\n\n'
              'נשמח לקבל טקסטים נוספים מכתבי הרב, שאין בהם בעיה של זכויות יוצרים, כדי לצרפם לספרייה.',
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _licenses(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final groups = <String, List<Map<String, dynamic>>>{};
                for (final e in snap.data!) {
                  (groups[e['group'] as String] ??= []).add(e);
                }
                return Column(children: [
                  for (final g in groups.entries)
                    Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 0,
                      color: context.pal.page,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6), side: BorderSide(color: context.pal.border)),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(g.key, style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.primary)),
                          for (final b in g.value) _BookLicenses(b),
                        ]),
                      ),
                    ),
                ]);
              },
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('תנאי השימוש של ספריא'),
                onPressed: () => _open('https://www.sefaria.org/terms'),
              ),
              TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('תנאי השימוש של ויקיטקסט'),
                onPressed: () => _open('https://foundation.wikimedia.org/wiki/Policy:Terms_of_Use'),
              ),
            ]),
        ])),
      ]),
    );
  }
}

class _BookLicenses extends StatelessWidget {
  final Map<String, dynamic> b;
  const _BookLicenses(this.b);

  @override
  Widget build(BuildContext context) {
    final editions = (b['editions'] as List).cast<Map<String, dynamic>>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(b['book'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        for (final e in editions) _EditionTile(e),
      ]),
    );
  }
}

class _EditionTile extends StatelessWidget {
  final Map<String, dynamic> v;
  const _EditionTile(this.v);

  static const _licenseUrls = {
    'CC-BY-NC': 'https://creativecommons.org/licenses/by-nc/4.0/',
    'CC-BY-SA': 'https://creativecommons.org/licenses/by-sa/4.0/',
    'CC-BY': 'https://creativecommons.org/licenses/by/4.0/',
    'CC0': 'https://creativecommons.org/publicdomain/zero/1.0/',
  };

  static String _licenseHe(String l) => switch (l) {
        'Public Domain' => 'נחלת הכלל (Public Domain)',
        'CC0' => 'CC0 – ללא זכויות שמורות',
        'CC-BY-NC' => 'CC BY-NC – שימוש לא מסחרי, עם ייחוס',
        'CC-BY-SA' => 'CC BY-SA – עם ייחוס ושיתוף זהה',
        'CC-BY' => 'CC BY – עם ייחוס',
        'unknown' || '' => 'לא צוין',
        _ => l,
      };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final license = v['license'] as String;
    final en = (v['titleEn'] as String?) ?? '';
    final source = (v['source'] as String?) ?? '';
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 12, top: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(v['title'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (en.isNotEmpty) Text(en, style: t.bodySmall, textDirection: TextDirection.ltr),
        Row(children: [
          const Text('רישיון: '),
          Flexible(
            child: InkWell(
              onTap: _licenseUrls[license] == null ? null : () => _open(_licenseUrls[license]!),
              child: Text(_licenseHe(license),
                  style: TextStyle(
                      decoration: _licenseUrls[license] == null ? null : TextDecoration.underline,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
        if ((v['note'] as String? ?? '').isNotEmpty) Text(v['note'] as String, style: t.bodySmall),
        if (source.isNotEmpty)
          InkWell(
            onTap: () => _open(source),
            child: Text('מקור: ${_decode(source)}',
                style: t.bodySmall?.copyWith(decoration: TextDecoration.underline),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
      ]),
    );
  }
}

/// קישורים מקודדים לפעמים חלקית – מציגים כמו שהם אם הפענוח נכשל.
String _decode(String url) {
  try {
    return Uri.decodeFull(url);
  } catch (_) {
    return url;
  }
}

Future<void> _open(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
}
