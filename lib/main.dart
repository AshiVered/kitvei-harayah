import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'ui/main_window.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'version.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // On the web, show the app's own right-click menu (add note, copy…) instead of the browser's.
  if (kIsWeb) BrowserContextMenu.disableContextMenu();
  // Font licenses appear in "רישיונות ספריות קוד".
  LicenseRegistry.addLicense(() async* {
    for (final (name, file) in [
      ('Frank Ruhl Libre', 'assets/fonts/OFL-FrankRuhlLibre.txt'),
      ('David Libre', 'assets/fonts/OFL-DavidLibre.txt'),
      ('Heebo', 'assets/fonts/OFL-Heebo.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([name], await rootBundle.loadString(file));
    }
  });
  runApp(const KitveiApp());
}

class KitveiApp extends StatefulWidget {
  const KitveiApp({super.key});

  @override
  State<KitveiApp> createState() => _KitveiAppState();
}

class _KitveiAppState extends State<KitveiApp> {
  late final Future<AppState> _state = AppState.create();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppState>(
      future: _state,
      builder: (context, snap) {
        final state = snap.data;
        Widget app() => MaterialApp(
          title: appName,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: state?.themeMode ?? ThemeMode.system,
          locale: const Locale('he'),
          supportedLocales: const [Locale('he')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: state != null
              ? const MainWindow()
              : Scaffold(
                  body: Center(
                    child: snap.hasError
                        ? Text('שגיאה בטעינת הספרייה:\n${snap.error}', textAlign: TextAlign.center)
                        : const CircularProgressIndicator(),
                  ),
                ),
        );
        if (state == null) return app();
        return AppScope(state: state, child: ListenableBuilder(listenable: state, builder: (_, _) => app()));
      },
    );
  }
}
