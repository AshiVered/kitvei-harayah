import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:material_ui/material_ui.dart';

import '../data/hebrew.dart';
import '../platform/platform.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../version.dart';

const _jsonType = XTypeGroup(
  label: 'גיבוי כתבי הראי״ה (JSON)',
  extensions: ['json'],
);

void _snack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

/// Saves settings, bookmarks, notes and reading history to a JSON file chosen by the user.
Future<void> exportBackup(BuildContext context) async {
  final app = AppScope.read(context);
  final d = DateTime.now();
  final name =
      'kitvei-harayah-backup-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.json';
  try {
    final saved = await saveTextFile(
      name,
      const JsonEncoder.withIndent(' ').convert(app.exportData(appVersion)),
      _jsonType,
    );
    if (!saved) return;
    if (context.mounted) {
      _snack(
        context,
        'הגיבוי נשמר: ${app.bookmarks.length} סימניות, ${app.notes.length} הערות',
      );
    }
  } catch (e) {
    if (context.mounted) _snack(context, 'שמירת הגיבוי נכשלה: $e');
  }
}

/// Replaces the current personal data with a backup file, after confirmation.
Future<void> importBackup(BuildContext context) async {
  final app = AppScope.read(context);
  final file = await openFile(acceptedTypeGroups: const [_jsonType]);
  if (file == null || !context.mounted) return;
  Map<String, dynamic> data;
  try {
    data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (data['format'] != AppState.backupFormat) throw const FormatException();
  } catch (_) {
    if (context.mounted) {
      _snack(context, 'הקובץ אינו קובץ גיבוי תקין של כתבי הראי״ה');
    }
    return;
  }
  if (!context.mounted) return;
  final nb = (data['bookmarks'] as List?)?.length ?? 0;
  final nn = (data['notes'] as List?)?.length ?? 0;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('ייבוא גיבוי'),
      content: Text(
        'בקובץ: $nb סימניות ו-$nn הערות.\n'
        'הייבוא יחליף את ההגדרות, הסימניות, ההערות והיסטוריית הקריאה הנוכחיים.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('ביטול'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('ייבוא'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  try {
    app.importData(data);
    _snack(context, 'הגיבוי יובא בהצלחה');
  } catch (e) {
    _snack(context, 'הייבוא נכשל: $e');
  }
}

const _sample =
    'הַצִּמָּאוֹן לְאֵל חַי, הוּא בָּא מִתּוֹךְ הַמְּלֵאוּת, לֹא מִתּוֹךְ הַחִסָּרוֹן; '
    'שֶׁהַנְּשָׁמָה מְלֵאָה הִיא, וְכָל מַה שֶּׁהִיא מִתְמַלֵּאת יוֹתֵר – הוֹלֶכֶת הִיא וּמִתְגַּעְגַּעַת.';

Future<void> showSettingsDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _SettingsDialog());

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = context.pal;
    Widget row(String label, Widget control) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 13.5)),
          ),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: control,
            ),
          ),
        ],
      ),
    );
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    'הגדרות',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'סגירה',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              row(
                'ערכת צבעים',
                SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('לפי המערכת'),
                    ),
                    ButtonSegment(value: ThemeMode.light, label: Text('בהירה')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('כהה')),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) =>
                      s.update((x) => x.themeMode = v.first),
                ),
              ),
              row(
                'גופן הטקסט',
                SegmentedButton<ReaderFont>(
                  showSelectedIcon: false,
                  segments: [
                    for (final f in ReaderFont.values)
                      ButtonSegment(value: f, label: Text(f.label)),
                  ],
                  selected: {s.font},
                  onSelectionChanged: (v) => s.update((x) => x.font = v.first),
                ),
              ),
              row(
                'גודל גופן',
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: s.fontSize.clamp(14, 40),
                        min: 14,
                        max: 40,
                        divisions: 26,
                        onChanged: (v) => s.update((x) => x.fontSize = v),
                      ),
                    ),
                    SizedBox(width: 30, child: Text('${s.fontSize.round()}')),
                  ],
                ),
              ),
              row(
                'מרווח שורות',
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: s.lineHeight.clamp(1.2, 2.4),
                        min: 1.2,
                        max: 2.4,
                        divisions: 12,
                        onChanged: (v) => s.update((x) => x.lineHeight = v),
                      ),
                    ),
                    SizedBox(
                      width: 30,
                      child: Text(s.lineHeight.toStringAsFixed(1)),
                    ),
                  ],
                ),
              ),
              row(
                'ניקוד',
                Switch(
                  value: s.showNiqqud,
                  onChanged: (v) => s.update((x) => x.showNiqqud = v),
                ),
              ),
              row(
                'יישור לשני הצדדים',
                Switch(
                  value: s.justify,
                  onChanged: (v) => s.update((x) => x.justify = v),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.page,
                  border: Border.all(color: p.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  s.showNiqqud ? _sample : stripNiqqud(_sample),
                  textAlign: s.justify ? TextAlign.justify : TextAlign.start,
                  style: TextStyle(
                    fontFamily: s.font.family,
                    fontSize: s.fontSize,
                    height: s.lineHeight,
                    color: p.ink,
                  ),
                ),
              ),
              if (s.personalData) ...[
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'גיבוי והעברה',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'ההגדרות, הסימניות, ההערות והיסטוריית הקריאה – בקובץ אחד, להעברה למחשב אחר.',
                  style: TextStyle(fontSize: 12.5, color: p.muted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => exportBackup(context),
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('ייצוא לקובץ…'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => importBackup(context),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('ייבוא מקובץ…'),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 10),
                Text(
                  'באתר, ההגדרות חלות רק עליכם ומתאפסות ביציאה מהאתר.',
                  style: TextStyle(fontSize: 12.5, color: p.muted),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (s.personalData)
                    TextButton.icon(
                      onPressed: s.history.isEmpty
                          ? null
                          : () {
                              for (final k in s.history.keys.toList()) {
                                s.clearHistory(k);
                              }
                            },
                      icon: const Icon(Icons.history_toggle_off, size: 18),
                      label: const Text('ניקוי היסטוריית הקריאה'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('סגירה'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
