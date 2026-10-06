import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'core/local_notifications.dart';
import 'core/theme.dart';
import 'screens/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The SIL Open Font License must accompany every bundled font.
  LicenseRegistry.addLicense(() async* {
    for (final (fonts, file) in const [
      (['Amiri', 'Amiri Quran'], 'AmiriQuran-OFL.txt'),
      (['Tajawal'], 'Tajawal-OFL.txt'),
      (['Noto Naskh Arabic'], 'NotoNaskhArabic-OFL.txt'),
    ]) {
      final license = await rootBundle.loadString('assets/fonts/$file');
      yield LicenseEntryWithLineBreaks(fonts, license);
    }
  });
  final state = AppState();
  runApp(ChangeNotifierProvider.value(value: state, child: const FadlApp()));
  await state.load();
  await LocalNotifications.instance.init();
  // Review reminders need no location; prayer items are skipped without one.
  unawaited(LocalNotifications.instance.reschedule(state));
}

class FadlApp extends StatelessWidget {
  const FadlApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      title: 'فضل',
      debugShowCheckedModeBanner: false,
      locale: state.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: state.themeMode,
      home: const AppGate(),
    );
  }
}

/// Splash while locally saved settings load.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.ready) {
      return Scaffold(
        backgroundColor: FadlColors.emerald,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'فضل',
                style: FadlFonts.heading(size: 56, color: Colors.white),
              ),
              Text(
                'قرآن • ذكر • دعاء',
                style: FadlFonts.ui(size: 16, color: FadlColors.goldLight),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(color: FadlColors.goldLight),
            ],
          ),
        ),
      );
    }
    return const AppShell();
  }
}
