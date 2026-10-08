import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audio_session/audio_session.dart';
import 'l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'core/adhan_catalog.dart';
import 'core/app_state.dart';
import 'core/local_notifications.dart';
import 'core/reciters.dart';
import 'core/theme.dart';
import 'screens/shell.dart';
import 'widgets/adaptive_layout.dart';

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
    for (final adhan in bundledAdhans) {
      yield LicenseEntryWithLineBreaks([
        'Adhan recording: ${adhan.nameEn}',
      ], adhan.credit);
    }
    yield const LicenseEntryWithLineBreaks(
      ['Tajweed colors'],
      'Tajweed annotations by Collin Fair, cpfair/quran-tajweed\n'
      'https://github.com/cpfair/quran-tajweed\n'
      'Licensed under CC BY 4.0: https://creativecommons.org/licenses/by/4.0/\n'
      'Re-anchored onto the mushaf text (tool/build_tajweed_asset.py).\n'
      'Underlying Uthmani text: Tanzil Quran Text, https://tanzil.net',
    );
    yield const LicenseEntryWithLineBreaks(
      ['Hadith texts'],
      'Arabic hadith texts, grades and English translations from\n'
      'https://github.com/fawazahmed0/hadith-api\n'
      'released into the public domain under the Unlicense.',
    );
  });
  // Recitation keeps playing with the screen locked or the iOS silent switch
  // on, and pauses for calls like any music player.
  unawaited(
    AudioSession.instance
        .then(
          (session) =>
              session.configure(const AudioSessionConfiguration.music()),
        )
        .catchError((Object e) => debugPrint('Audio session setup failed: $e')),
  );
  final state = AppState();
  runApp(ChangeNotifierProvider.value(value: state, child: const FadlApp()));
  await state.load();
  // Cached everyayah reciters are available at once; refreshed online.
  unawaited(ReciterCatalog.instance.load());
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
      // Tablets: a centred frame instead of stretching across the screen.
      builder: (context, child) => TabletFrame(child: child!),
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
