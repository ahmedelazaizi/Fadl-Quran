import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/local_notifications.dart';
import '../core/local_user_data.dart';
import '../core/offline_tafsir.dart';
import '../core/offline_tajweed.dart';
import '../core/reciters.dart';
import '../core/theme.dart';
import '../l10n/prayer_labels.dart';
import '../widgets/common.dart';
import '../widgets/location_picker.dart';
import 'prayer/prayer_settings_sheets.dart';
import 'library_screen.dart';

String _uiNum(BuildContext context, Object number) =>
    Localizations.localeOf(context).languageCode == 'en'
    ? '$number'
    : arNum(number);

String _uiTime(BuildContext context, String time) {
  if (Localizations.localeOf(context).languageCode == 'ar') return hm12(time);
  final parts = time.split(':');
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
  );
}

const _appVersion = '1.0.0';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppLocalizations get l =>
      (AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('ar')));

  final Future<List<Map<String, dynamic>>> _reciters = Future.value(reciters);
  late Future<List<Map<String, dynamic>>> _tafsirs = _loadTafsirs();

  /// Server editions, or the downloadable offline editions without a backend.
  Future<List<Map<String, dynamic>>> _loadTafsirs() async {
    if (Api.hasBackend) {
      final r = await Api.instance.get('/quran/editions');
      return ((r as Map)['editions'] as List)
          .cast<Map<String, dynamic>>()
          .where((e) => e['type'] == 'TAFSIR')
          .toList();
    }
    await OfflineTafsir.instance.ready();
    return [
      for (final e in offlineTafsirEditions)
        {
          'slug': e.slug,
          'nameAr': e.nameAr,
          'source': OfflineTafsir.instance.isDownloaded(e.slug)
              ? 'LOCAL'
              : 'DOWNLOAD',
        },
    ];
  }

  double? _fontDraft;

  Future<void> _settings(
    Map<String, Object?> patch, {
    bool reschedule = false,
  }) async {
    final state = context.read<AppState>();
    try {
      await state.updateSettings(patch);
      if (reschedule) {
        LocalNotifications.instance.reschedule(state);
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  Future<void> _notify(Map<String, Object?> patch) async {
    final state = context.read<AppState>();
    try {
      await state.updateNotifications(patch);
      LocalNotifications.instance.reschedule(state);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.settings;
    final n = state.notifications;
    final scheme = Theme.of(context).colorScheme;
    final enabled = n['enabled'] != false;

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _ProfileCard(dedicatee: state.dedicatee, onEdit: _editDedicatee),
          SettingRow(
            icon: Icons.language_rounded,
            title: l.language,
            subtitle: state.language == 'ar' ? l.arabic : l.english,
            trailing: DropdownButton<String>(
              value: state.language,
              items: [
                DropdownMenuItem(value: 'ar', child: Text(l.arabic)),
                DropdownMenuItem(value: 'en', child: Text(l.english)),
              ],
              onChanged: (language) {
                if (language != null) state.setLanguage(language);
              },
            ),
          ),
          const SizedBox(height: 20),

          // ───────────── Appearance ─────────────
          SectionTitle(l.appearance),
          FadlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.appTheme,
                  style: FadlFonts.ui(size: 15, weight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'light',
                        label: Text(l.light),
                        icon: Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: 'dark',
                        label: Text(l.dark),
                        icon: Icon(Icons.dark_mode_outlined),
                      ),
                      ButtonSegment(
                        value: 'auto',
                        label: Text(l.automatic),
                        icon: Icon(Icons.brightness_auto_outlined),
                      ),
                    ],
                    selected: {(s['theme'] as String?) ?? 'light'},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => _settings({'theme': v.first}),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.mushafFontSize,
                        style: FadlFonts.ui(size: 15, weight: FontWeight.w700),
                      ),
                    ),
                    Badge2(
                      '${_uiNum(context, (_fontDraft ?? state.quranFontSize).round())} px',
                    ),
                  ],
                ),
                Slider(
                  min: 18,
                  max: 32,
                  divisions: 14,
                  value: (_fontDraft ?? state.quranFontSize).clamp(18, 32),
                  activeColor: FadlColors.sage,
                  onChanged: (v) => setState(() => _fontDraft = v),
                  onChangeEnd: (v) async {
                    await _settings({'fontSize': v.round()});
                    if (mounted) setState(() => _fontDraft = null);
                  },
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ ﴿١﴾ ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ ﴿٢﴾',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: FadlFonts.scripture(
                      size: _fontDraft ?? state.quranFontSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FadlCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _reciters,
                  builder: (context, snap) => SettingRow(
                    icon: Icons.headphones_outlined,
                    title: l.defaultReciter,
                    subtitle:
                        _nameOf(snap.data, 'id', state.reciterId) ??
                        state.reciterId,
                    onTap: () => _pickFrom(
                      title: l.defaultReciter,
                      future: _reciters,
                      idKey: 'id',
                      current: state.reciterId,
                      subtitle: (r) => r['style'] as String?,
                      onPick: (id) => _settings({'reciterId': id}),
                    ),
                  ),
                ),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _tafsirs,
                  builder: (context, snap) => SettingRow(
                    icon: Icons.menu_book_outlined,
                    title: l.defaultTafsir,
                    trailing: IconButton(
                      tooltip: l.library,
                      icon: const Icon(Icons.local_library_outlined),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const LibraryScreen(),
                        ),
                      ),
                    ),
                    subtitle:
                        _nameOf(snap.data, 'slug', s['tafsirSlug']) ??
                        '${s['tafsirSlug'] ?? ''}',
                    onTap: () => _pickFrom(
                      title: l.defaultTafsir,
                      future: _tafsirs,
                      idKey: 'slug',
                      current: s['tafsirSlug'],
                      subtitle: (e) => e['source'] == 'LOCAL'
                          ? l.availableOffline
                          : e['source'] == 'DOWNLOAD'
                          ? l.needsDownload
                          : l.loadsOnDemand,
                      onPick: (slug) => _settings({'tafsirSlug': slug}),
                    ),
                  ),
                ),
                SettingRow(
                  icon: Icons.local_library_outlined,
                  title: l.library,
                  subtitle: l.manageLibrary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const LibraryScreen(),
                    ),
                  ),
                ),
                SettingRow(
                  icon: Icons.color_lens_outlined,
                  title: l.coloredTajweed,
                  trailing: IconButton(
                    tooltip: l.library,
                    icon: const Icon(Icons.local_library_outlined),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const LibraryScreen(),
                      ),
                    ),
                  ),
                  subtitle: l.optionalSource(tajweedSource),
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        const SafeArea(child: _OfflineTajweedSheet()),
                  ),
                ),
                if (!Api.hasBackend)
                  SettingRow(
                    icon: Icons.download_for_offline_outlined,
                    title: l.offlineTafsir,
                    subtitle: l.optionalDownload,
                    onTap: _openOfflineTafsir,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ───────────── Location & prayer ─────────────
          SectionTitle(l.locationPrayer),
          FadlCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                SettingRow(
                  icon: Icons.location_on_outlined,
                  title: l.location,
                  subtitle: state.hasLocation
                      ? locationLabel(l, s['locationName'] as String?)
                      : l.notSet,
                  onTap: () => showLocationPicker(context),
                ),
                SettingRow(
                  icon: Icons.calculate_outlined,
                  title: l.calculationMethod,
                  subtitle: calculationLabel(
                    l,
                    '${s['calcMethod'] ?? 'UmmAlQura'}',
                  ),
                  onTap: () => showCalcMethodSheet(context),
                ),
                SettingRow(
                  icon: Icons.schedule_rounded,
                  title: l.asrSchool,
                  subtitle: madhabLabel(l, '${s['madhab'] ?? 'shafi'}'),
                  onTap: () => showMadhabSheet(context),
                ),
                SettingRow(
                  icon: Icons.calendar_month_outlined,
                  title: l.hijriAdjustment,
                  trailing: HijriAdjustmentStepper(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ───────────── Notifications ─────────────
          SectionTitle(l.notifications),
          FadlCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                _switch(
                  Icons.notifications_active_outlined,
                  l.enableNotifications,
                  l.notificationDescription,
                  enabled,
                  (v) => _notify({'enabled': v}),
                ),
                if (enabled) ...[
                  const Divider(height: 8),
                  SettingRow(
                    icon: Icons.alarm_outlined,
                    title: l.preAdhanAlert,
                    subtitle: l.perPrayerAdhan,
                    trailing: DropdownButton<int>(
                      value:
                          const [
                            0,
                            5,
                            10,
                            15,
                            30,
                          ].contains(n['preAlertMinutes'])
                          ? n['preAlertMinutes'] as int
                          : 15,
                      underline: const SizedBox.shrink(),
                      borderRadius: BorderRadius.circular(12),
                      items: [
                        for (final m in const [0, 5, 10, 15, 30])
                          DropdownMenuItem(
                            value: m,
                            child: Text(
                              m == 0
                                  ? l.off
                                  : l.minutesShort(_uiNum(context, m)),
                              style: FadlFonts.ui(size: 14),
                            ),
                          ),
                      ],
                      onChanged: (v) => _notify({'preAlertMinutes': v}),
                    ),
                  ),
                  _timeRow(
                    Icons.wb_sunny_outlined,
                    l.morningAthkar,
                    'morningAthkarTime',
                    n,
                  ),
                  _timeRow(
                    Icons.nights_stay_outlined,
                    l.eveningAthkar,
                    'eveningAthkarTime',
                    n,
                  ),
                  _timeRow(
                    Icons.bedtime_outlined,
                    l.sleepAthkar,
                    'sleepAthkarTime',
                    n,
                  ),
                  _timeRow(
                    Icons.auto_stories_outlined,
                    l.quranReviewReminder,
                    'quranReviewTime',
                    n,
                    hint: l.quranReviewReminderHint,
                  ),
                  const Divider(height: 8),
                  _switch(
                    Icons.dark_mode_outlined,
                    l.qiyam,
                    l.qiyamDescription,
                    n['qiyamEnabled'] == true,
                    (v) => _notify({'qiyamEnabled': v}),
                  ),
                  _switch(
                    Icons.light_mode_outlined,
                    l.duha,
                    l.duhaDescription,
                    n['duhaEnabled'] == true,
                    (v) => _notify({'duhaEnabled': v}),
                  ),
                  _switch(
                    Icons.auto_stories_outlined,
                    l.kahf,
                    l.kahfDescription,
                    n['fridayKahf'] == true,
                    (v) => _notify({'fridayKahf': v}),
                  ),
                  _switch(
                    Icons.front_hand_outlined,
                    l.fridayHour,
                    l.fridayHourDescription,
                    n['fridayHour'] == true,
                    (v) => _notify({'fridayHour': v}),
                  ),
                  _switch(
                    Icons.restaurant_outlined,
                    l.mondayThursday,
                    l.mondayThursdayDescription,
                    n['mondayThursdayFast'] == true,
                    (v) => _notify({'mondayThursdayFast': v}),
                  ),
                  _switch(
                    Icons.brightness_3_outlined,
                    l.whiteDays,
                    l.whiteDaysDescription,
                    n['whiteDaysFast'] == true,
                    (v) => _notify({'whiteDaysFast': v}),
                  ),
                  _switch(
                    Icons.menu_book_rounded,
                    l.planReminder,
                    l.planReminderDescription,
                    n['khatmaReminder'] == true,
                    (v) => _notify({'khatmaReminder': v}),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ───────────── Data & about ─────────────
          SectionTitle(l.dataAbout),
          FadlCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                SettingRow(
                  icon: Icons.delete_forever_outlined,
                  title: l.deleteMyData,
                  subtitle: l.deleteDescription,
                  onTap: _confirmDelete,
                ),
                SettingRow(
                  icon: Icons.info_outline_rounded,
                  title: 'فضل — ${l.appTagline}',
                  subtitle: l.version(_appVersion),
                  trailing: SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _nameOf(List<Map<String, dynamic>>? items, String idKey, Object? id) {
    if (items == null) return null;
    for (final i in items) {
      if (i[idKey] == id) return i['nameAr'] as String?;
    }
    return null;
  }

  Widget _switch(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) => SettingRow(
    icon: icon,
    title: title,
    subtitle: subtitle,
    trailing: Switch(value: value, onChanged: onChanged),
    onTap: () => onChanged(!value),
  );

  Widget _timeRow(
    IconData icon,
    String title,
    String key,
    Map<String, dynamic> n, {
    String? hint,
  }) {
    final value = n[key] as String?;
    final schedule = value == null ? l.off : l.dailyAt(_uiTime(context, value));
    return SettingRow(
      icon: icon,
      title: title,
      subtitle: hint == null ? schedule : '$schedule\n$hint',
      onTap: () => _pickTime(key, value),
      trailing: Switch(
        value: value != null,
        onChanged: (on) => on ? _pickTime(key, value) : _notify({key: null}),
      ),
    );
  }

  Future<void> _pickTime(String key, String? current) async {
    final parts =
        (current ??
                (key == 'eveningAthkarTime'
                    ? '17:00'
                    : key == 'sleepAthkarTime'
                    ? '22:00'
                    : key == 'quranReviewTime'
                    ? '20:00'
                    : '06:00'))
            .split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (picked == null) return;
    String two(int v) => v.toString().padLeft(2, '0');
    await _notify({key: '${two(picked.hour)}:${two(picked.minute)}'});
  }

  Future<void> _pickFrom({
    required String title,
    required Future<List<Map<String, dynamic>>> future,
    required String idKey,
    required Object? current,
    required String? Function(Map<String, dynamic>) subtitle,
    required ValueChanged<String> onPick,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.75,
          ),
          child: AsyncView<List<Map<String, dynamic>>>(
            load: () => future,
            builder: (_, items, _) => ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                Text(title, style: FadlFonts.heading(size: 20)),
                const SizedBox(height: 8),
                for (final it in items)
                  ListTile(
                    title: Text(
                      it['nameAr'] as String,
                      style: FadlFonts.ui(size: 15),
                    ),
                    subtitle: subtitle(it) == null
                        ? null
                        : Text(subtitle(it)!, style: FadlFonts.ui(size: 12)),
                    selected: it[idKey] == current,
                    trailing: it[idKey] == current
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: FadlColors.sage,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onPick(it[idKey] as String);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openOfflineTafsir() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const SafeArea(child: _OfflineTafsirSheet()),
    );
    if (mounted) {
      setState(() {
        _tafsirs = _loadTafsirs();
      });
    }
  }

  Future<void> _editDedicatee() async {
    final controller = TextEditingController(
      text: context.read<AppState>().dedicatee,
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.recipientName, style: FadlFonts.heading(size: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          decoration: InputDecoration(hintText: l.recipientExample),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(l.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    await _settings({'dedicateeName': name});
    if (mounted) showToast(context, l.nameSaved);
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.deleteMyData, style: FadlFonts.heading(size: 18)),
        content: Text(
          Api.hasBackend ? l.deleteBackendWarning : l.deleteLocalWarning,
          style: FadlFonts.ui(size: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: FadlColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final state = context.read<AppState>();
    try {
      if (Api.hasBackend) await Api.instance.delete('/me');
      await LocalUserData.instance.clearAll();
      await LocalNotifications.instance.plugin.cancelAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fadl.deviceSecret');
      await prefs.remove('fadl.accessToken');
      await prefs.remove('fadl.uiLanguage');
      if (!Api.hasBackend) {
        // AppState's local copies; defaults return on reload.
        await prefs.remove('fadl.settings');
        await prefs.remove('fadl.notifications');
      }
      Api.instance.reset();
      await state.load();
      if (mounted) showToast(context, l.myDataDeleted);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } catch (_) {
      if (mounted) {
        showToast(context, l.restartAfterDelete);
      }
    }
  }
}

class _OfflineTajweedSheet extends StatefulWidget {
  const _OfflineTajweedSheet();

  @override
  State<_OfflineTajweedSheet> createState() => _OfflineTajweedSheetState();
}

class _OfflineTajweedSheetState extends State<_OfflineTajweedSheet> {
  AppLocalizations get l =>
      (AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('ar')));

  final store = OfflineTajweed.instance;
  int _bytes = 0;

  @override
  void initState() {
    super.initState();
    store.addListener(_refresh);
    _refresh();
  }

  @override
  void dispose() {
    store.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final bytes = await store.size();
      if (mounted) setState(() => _bytes = bytes);
    } on Object {
      if (mounted) setState(() {});
    }
  }

  Future<void> _download() async {
    try {
      await store.download();
      if (mounted) showToast(context, l.tajweedDownloaded);
    } on TajweedDownloadException catch (error) {
      if (mounted) showToast(context, error.message);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l.deleteTajweedQuestion),
        content: Text(l.tajweedRedownload),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await store.delete();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(tajweedPreferenceKey);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    shrinkWrap: true,
    padding: const EdgeInsets.all(16),
    children: [
      Text(l.coloredTajweed, style: FadlFonts.heading(size: 20)),
      const SizedBox(height: 8),
      Text(
        l.tajweedDetails(
          tajweedSource,
          tajweedSourceUrl,
          prayerBytes(context, tajweedApproxBytes),
          prayerBytes(context, tajweedMaxBytes),
          prayerBytes(context, _bytes),
        ),
        style: FadlFonts.ui(size: 13, height: 1.7),
      ),
      if (store.isDownloading) ...[
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: store.expectedBytes == null || store.expectedBytes == 0
              ? null
              : store.receivedBytes / store.expectedBytes!,
        ),
        Text(l.downloadingSize(prayerBytes(context, store.receivedBytes))),
      ] else
        ListTile(
          title: Text(
            store.isDownloaded
                ? l.downloadedSize(prayerBytes(context, _bytes))
                : l.notDownloaded,
          ),
          trailing: IconButton(
            tooltip: store.isDownloaded ? l.delete : l.download,
            onPressed: store.isDownloaded ? _delete : _download,
            icon: Icon(
              store.isDownloaded ? Icons.delete_outline : Icons.download,
            ),
          ),
        ),
    ],
  );
}

/// Opt-in download / deletion of tafsir editions for offline reading.
class _OfflineTafsirSheet extends StatefulWidget {
  const _OfflineTafsirSheet();

  @override
  State<_OfflineTafsirSheet> createState() => _OfflineTafsirSheetState();
}

class _OfflineTafsirSheetState extends State<_OfflineTafsirSheet> {
  AppLocalizations get l =>
      (AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('ar')));

  final store = OfflineTafsir.instance;
  final Map<String, int> _sizes = {};

  @override
  void initState() {
    super.initState();
    store.addListener(_refreshSizes);
    _refreshSizes();
  }

  @override
  void dispose() {
    store.removeListener(_refreshSizes);
    super.dispose();
  }

  Future<void> _refreshSizes() async {
    try {
      await store.ready();
      final sizes = {
        for (final e in offlineTafsirEditions) e.slug: await store.size(e.slug),
      };
      if (mounted) setState(() => _sizes.addAll(sizes));
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _download(TafsirEdition e) async {
    try {
      await store.download(e.slug);
      if (mounted) showToast(context, l.downloadedTafsir(e.nameAr));
    } on TafsirDownloadException catch (error) {
      if (mounted) showToast(context, error.message);
    }
  }

  Future<void> _delete(TafsirEdition e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          l.deleteNamed(e.nameAr),
          style: FadlFonts.heading(size: 18),
        ),
        content: Text(l.tafsirRedownload),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: FadlColors.error),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok == true) await store.delete(e.slug);
  }

  @override
  Widget build(BuildContext context) {
    final total = _sizes.values.fold<int>(0, (a, b) => a + b);
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text(l.offlineTafsir, style: FadlFonts.heading(size: 20)),
        const SizedBox(height: 4),
        Text(
          l.tafsirDownloadDescription(prayerBytes(context, total)),
          style: FadlFonts.ui(size: 13, height: 1.6),
        ),
        const SizedBox(height: 8),
        for (final e in offlineTafsirEditions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              store.isDownloaded(e.slug)
                  ? Icons.offline_pin_rounded
                  : Icons.menu_book_outlined,
              color: FadlColors.sage,
            ),
            title: Text(e.nameAr, style: FadlFonts.ui(size: 15)),
            subtitle: Text(
              store.isDownloading(e.slug)
                  ? l.downloading
                  : store.isDownloaded(e.slug)
                  ? l.downloadedSize(prayerBytes(context, _sizes[e.slug] ?? 0))
                  : l.notDownloadedSize(prayerBytes(context, e.approxBytes)),
              style: FadlFonts.ui(size: 12),
            ),
            trailing: store.isDownloading(e.slug)
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : store.isDownloaded(e.slug)
                ? IconButton(
                    tooltip: l.delete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: FadlColors.error,
                    ),
                    onPressed: () => _delete(e),
                  )
                : IconButton(
                    tooltip: l.download,
                    icon: const Icon(Icons.download_rounded),
                    onPressed: () => _download(e),
                  ),
          ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.dedicatee, required this.onEdit});
  final String dedicatee;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [FadlColors.emerald, FadlColors.primary],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                  border: Border.all(color: FadlColors.goldLight),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: FadlColors.goldLight,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  (AppLocalizations.of(context) ??
                          lookupAppLocalizations(const Locale('ar')))
                      .accountDescription,
                  style: FadlFonts.ui(
                    size: 13.5,
                    color: Colors.white,
                    weight: FontWeight.w600,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.volunteer_activism_rounded,
                      color: FadlColors.goldLight,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (AppLocalizations.of(context) ??
                                    lookupAppLocalizations(const Locale('ar')))
                                .dedicationLabel,
                            style: FadlFonts.ui(
                              size: 12,
                              color: FadlColors.onEmerald,
                            ),
                          ),
                          Text(
                            dedicatee,
                            style: FadlFonts.heading(
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.edit_outlined,
                      color: FadlColors.goldLight,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
