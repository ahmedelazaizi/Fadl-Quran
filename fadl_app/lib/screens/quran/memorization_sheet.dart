import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/memorization.dart';
import '../../core/quran_audio.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

void openMemorizationSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _MemorizationSheet(),
  );
}

class _MemorizationSheet extends StatefulWidget {
  const _MemorizationSheet();

  @override
  State<_MemorizationSheet> createState() => _MemorizationSheetState();
}

class _MemorizationSheetState extends State<_MemorizationSheet> {
  final audio = QuranAudio.instance;
  late MemorizationSettings settings = audio.settings;
  static const repeats = [1, 2, 3, 5, 10, 0];

  Widget _repeats(String label, int selected, ValueChanged<int> onChange) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: FadlFonts.ui(size: 15, weight: FontWeight.w700)),
          Wrap(
            spacing: 6,
            children: [
              for (final count in repeats)
                ChoiceChip(
                  label: Text(
                    count == 0
                        ? AppLocalizations.of(context)!.unlimited
                        : _number(count),
                  ),
                  selected: count == selected,
                  onSelected: (_) => setState(() => onChange(count)),
                ),
            ],
          ),
        ],
      );

  String _number(Object number) =>
      Localizations.localeOf(context).languageCode == 'ar'
      ? arNum(number)
      : '$number';

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppLocalizations.of(context)!.memorizationSettings,
              style: FadlFonts.heading(size: 20),
            ),
            _repeats(
              AppLocalizations.of(context)!.repeatEachVerse,
              settings.ayahRepeats,
              (count) => settings = settings.copyWith(ayahRepeats: count),
            ),
            SwitchListTile(
              title: Text(AppLocalizations.of(context)!.repeatSegment),
              value: settings.hasRange,
              onChanged: (enabled) => setState(
                () => settings = enabled
                    ? settings.copyWith(
                        rangeStart: audio.ayahNumber == 0
                            ? 1
                            : audio.ayahNumber,
                        rangeEnd: audio.ayahNumber == 0 ? 1 : audio.ayahNumber,
                      )
                    : settings.copyWith(clearRange: true),
              ),
            ),
            if (settings.hasRange && audio.ayahs.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: _ayahPicker(
                      AppLocalizations.of(context)!.fromVerse,
                      settings.rangeStart!,
                      (number) {
                        settings = settings.copyWith(
                          rangeStart: number,
                          rangeEnd: settings.rangeEnd!.clamp(
                            number,
                            audio.ayahs.length,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ayahPicker(
                      AppLocalizations.of(context)!.toVerse,
                      settings.rangeEnd!,
                      (number) {
                        settings = settings.copyWith(
                          rangeEnd: number,
                          rangeStart: settings.rangeStart!.clamp(1, number),
                        );
                      },
                    ),
                  ),
                ],
              ),
              _repeats(
                AppLocalizations.of(context)!.repeatPassage,
                settings.rangeRepeats,
                (count) => settings = settings.copyWith(rangeRepeats: count),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.recitationPause,
              style: FadlFonts.ui(size: 15, weight: FontWeight.w700),
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final (mode, label) in [
                  (0, AppLocalizations.of(context)!.off),
                  (1, AppLocalizations.of(context)!.verseLength),
                  (2, AppLocalizations.of(context)!.doubleVerseLength),
                  (3, AppLocalizations.of(context)!.secondsCount(_number(3))),
                  (5, AppLocalizations.of(context)!.secondsCount(_number(5))),
                  (10, AppLocalizations.of(context)!.secondsCount(_number(10))),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: settings.pauseMode == mode,
                    onSelected: (_) => setState(
                      () => settings = settings.copyWith(pauseMode: mode),
                    ),
                  ),
              ],
            ),
            Text(
              AppLocalizations.of(context)!.recitationSpeed,
              style: FadlFonts.ui(size: 15, weight: FontWeight.w700),
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final speed in [0.75, 1.0, 1.25, 1.5])
                  ChoiceChip(
                    label: Text(
                      AppLocalizations.of(
                        context,
                      )!.speedMultiplier(_number(speed)),
                    ),
                    selected: settings.speed == speed,
                    onSelected: (_) => setState(
                      () => settings = settings.copyWith(speed: speed),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                await audio.updateSettings(settings);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(AppLocalizations.of(context)!.saveSettings),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _ayahPicker(String label, int selected, ValueChanged<int> onChange) =>
      DropdownButtonFormField<int>(
        initialValue: selected,
        decoration: InputDecoration(labelText: label),
        items: [
          for (var number = 1; number <= audio.ayahs.length; number++)
            DropdownMenuItem(value: number, child: Text(_number(number))),
        ],
        onChanged: (number) {
          if (number != null) setState(() => onChange(number));
        },
      );
}
