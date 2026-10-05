import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/adhan_service.dart';
import '../../core/app_state.dart';
import '../../core/local_notifications.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_labels.dart';
import '../../widgets/common.dart';

const adhanModeIcons = {
  'adhan': Icons.campaign_outlined,
  'notify': Icons.notifications_active_outlined,
  'silent': Icons.notifications_off_outlined,
};

/// Saves [mode] for [prayer] and keeps the legacy bool map (synced with the
/// backend and the general settings screen) consistent, then reschedules.
Future<void> setPrayerMode(AppState state, String prayer, String mode) async {
  await state.updateNotifications({
    'adhanModes': {prayer: mode},
    'adhan': {prayer: mode != 'silent'},
  });
  unawaited(LocalNotifications.instance.reschedule(state));
}

Future<void> openAdhanSettings(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const AdhanSettingsScreen()),
);

class AdhanSettingsScreen extends StatefulWidget {
  const AdhanSettingsScreen({super.key});

  @override
  State<AdhanSettingsScreen> createState() => _AdhanSettingsScreenState();
}

class _AdhanSettingsScreenState extends State<AdhanSettingsScreen>
    with WidgetsBindingObserver {
  final _adhan = AdhanService.instance;
  AppLocalizations get _l => prayerL(context);
  List<AdhanSound> _imported = const [];
  String? _previewing;
  bool? _batteryExempt;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshImports();
    _refreshBattery();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_previewing != null) unawaited(_adhan.stopPreview().catchError((_) {}));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user may come back from the battery settings page.
    if (state == AppLifecycleState.resumed) _refreshBattery();
  }

  Future<void> _refreshImports() async {
    try {
      final list = await _adhan.listImported();
      if (mounted) setState(() => _imported = list);
    } on PlatformException catch (e) {
      _toast(e.message ?? _l.importsReadError);
    }
  }

  Future<void> _refreshBattery() async {
    try {
      final exempt = await _adhan.isIgnoringBatteryOptimizations();
      if (mounted) setState(() => _batteryExempt = exempt);
    } on PlatformException {
      // Unknown status; the guidance and button stay visible.
    }
  }

  void _toast(String message) {
    if (mounted) showToast(context, message);
  }

  Future<void> _update(Map<String, Object?> patch) async {
    final state = context.read<AppState>();
    await state.updateNotifications(patch);
    unawaited(LocalNotifications.instance.reschedule(state));
  }

  Future<void> _togglePreview(String soundId) async {
    try {
      if (_previewing == soundId) {
        await _adhan.stopPreview();
        setState(() => _previewing = null);
      } else {
        await _adhan.preview(soundId);
        setState(() => _previewing = soundId);
      }
    } on PlatformException catch (e) {
      _toast(e.message ?? _l.previewError);
    }
  }

  Future<void> _import(String kind) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final sound = await _adhan.pickAndImport(kind: kind);
      if (sound == null) return;
      await _refreshImports();
      await _update({kind == 'fajr' ? 'fajrSound' : 'regularSound': sound.id});
      _toast(_l.importedSound(sound.name));
    } on PlatformException catch (e) {
      _toast(e.message ?? _l.importError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(AdhanSound sound) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_l.deleteFile),
        content: Text(_l.confirmDeleteSound(sound.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      if (_previewing == sound.id) {
        await _adhan.stopPreview();
        _previewing = null;
      }
      await _adhan.deleteImported(sound.id);
      if (!mounted) return;
      final notifications = context.read<AppState>().notifications;
      if (notifications['fajrSound'] == sound.id) {
        await _update({'fajrSound': null});
      } else if (notifications['regularSound'] == sound.id) {
        await _update({'regularSound': defaultAdhanSound});
      }
      await _refreshImports();
      _toast(_l.fileDeleted);
    } on PlatformException catch (e) {
      _toast(e.message ?? _l.fileDeleteError);
    }
  }

  Future<void> _testAlarm() async {
    final notifications = context.read<AppState>().notifications;
    try {
      await _adhan.testAlarm(
        soundForPrayer(notifications, 'dhuhr')!,
        respectSilent: notifications['respectSilent'] == true,
      );
      _toast(_l.testAdhanScheduled);
    } on PlatformException catch (e) {
      _toast(e.message ?? _l.testAdhanError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final notifications = state.notifications;
    final supported = _adhan.supported;
    return Scaffold(
      appBar: AppBar(title: Text(prayerL(context).adhanSettings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (!supported)
            _Note(
              icon: Icons.info_outline_rounded,
              text: prayerL(context).adhanAndroidOnly,
            ),
          if (notifications['enabled'] == false)
            _Note(
              icon: Icons.notifications_paused_outlined,
              text: prayerL(context).adhanDisabled,
            ),
          SectionTitle(prayerL(context).perPrayerAlert),
          FadlCard(
            child: Column(
              children: [
                for (final prayer in prayerNames.keys)
                  _PrayerModeRow(
                    prayer: prayer,
                    mode: prayerMode(notifications, prayer),
                    fajrFallback:
                        prayer == 'fajr' &&
                        soundForPrayer(notifications, 'fajr') == null,
                    onChanged: (mode) => setPrayerMode(state, prayer, mode),
                  ),
              ],
            ),
          ),
          if (supported) ...[
            const SizedBox(height: 8),
            SectionTitle(prayerL(context).adhanSound),
            _SoundCard(
              title: prayerL(context).prayerFajr,
              kind: 'fajr',
              selected: soundForPrayer(notifications, 'fajr'),
              builtIn: null,
              imported: [
                for (final s in _imported)
                  if (s.kind == 'fajr') s,
              ],
              previewing: _previewing,
              busy: _busy,
              onSelect: (id) => _update({'fajrSound': id}),
              onPreview: _togglePreview,
              onImport: () => _import('fajr'),
              onDelete: _delete,
            ),
            const SizedBox(height: 8),
            _Note(
              icon: Icons.nights_stay_outlined,
              text: prayerL(context).fajrSoundNotice,
            ),
            const SizedBox(height: 8),
            _SoundCard(
              title: prayerL(context).otherPrayers,
              kind: 'regular',
              selected: soundForPrayer(notifications, 'dhuhr'),
              builtIn: defaultAdhanSound,
              imported: [
                for (final s in _imported)
                  if (s.kind == 'regular') s,
              ],
              previewing: _previewing,
              busy: _busy,
              onSelect: (id) => _update({'regularSound': id}),
              onPreview: _togglePreview,
              onImport: () => _import('regular'),
              onDelete: _delete,
            ),
            const SizedBox(height: 8),
            SectionTitle(prayerL(context).adhanOptions),
            FadlCard(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Column(
                children: [
                  SwitchListTile(
                    value: notifications['respectSilent'] == true,
                    onChanged: (value) => _update({'respectSilent': value}),
                    secondary: const Icon(
                      Icons.vibration_rounded,
                      color: FadlColors.sage,
                    ),
                    title: Text(
                      prayerL(context).respectSilent,
                      style: FadlFonts.ui(size: 15, weight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      prayerL(context).respectSilentHint,
                      style: FadlFonts.ui(size: 12.5),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.alarm_on_rounded,
                      color: FadlColors.sage,
                    ),
                    title: Text(
                      prayerL(context).testAdhan,
                      style: FadlFonts.ui(size: 15, weight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      prayerL(context).testAdhanHint,
                      style: FadlFonts.ui(size: 12.5),
                    ),
                    onTap: _testAlarm,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SectionTitle(prayerL(context).batterySaving),
            _BatteryCard(
              exempt: _batteryExempt,
              onOpen: () async {
                try {
                  await _adhan.openBatterySettings();
                } on PlatformException catch (e) {
                  _toast(e.message ?? _l.batterySettingsError);
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: FadlCard(
      color: Theme.of(context).colorScheme.surfaceContainer,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: FadlColors.gold),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: FadlFonts.ui(size: 13))),
        ],
      ),
    ),
  );
}

class _PrayerModeRow extends StatelessWidget {
  const _PrayerModeRow({
    required this.prayer,
    required this.mode,
    required this.fajrFallback,
    required this.onChanged,
  });
  final String prayer;
  final String mode;
  final bool fajrFallback;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // Sunrise is not a prayer time with an adhan.
    final modes = prayer == 'sunrise'
        ? const ['notify', 'silent']
        : adhanModeValues;
    final shown = modes.contains(mode) ? mode : 'notify';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prayerLabel(prayerL(context), prayer),
            style: FadlFonts.ui(size: 15, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                for (final m in modes)
                  ButtonSegment(
                    value: m,
                    label: Text(adhanModeLabel(prayerL(context), m)),
                    icon: Icon(adhanModeIcons[m], size: 18),
                  ),
              ],
              selected: {shown},
              onSelectionChanged: (value) => onChanged(value.single),
            ),
          ),
          if (fajrFallback && shown == 'adhan')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                prayerL(context).fajrImportHint,
                style: FadlFonts.ui(size: 12, color: FadlColors.gold),
              ),
            ),
        ],
      ),
    );
  }
}

class _SoundCard extends StatelessWidget {
  const _SoundCard({
    required this.title,
    required this.kind,
    required this.selected,
    required this.builtIn,
    required this.imported,
    required this.previewing,
    required this.busy,
    required this.onSelect,
    required this.onPreview,
    required this.onImport,
    required this.onDelete,
  });
  final String title;
  final String kind;
  final String? selected;

  /// Bundled sound offered for this kind, or null (Fajr).
  final String? builtIn;
  final List<AdhanSound> imported;
  final String? previewing;
  final bool busy;
  final ValueChanged<String?> onSelect;
  final ValueChanged<String> onPreview;
  final VoidCallback onImport;
  final ValueChanged<AdhanSound> onDelete;

  @override
  Widget build(BuildContext context) {
    return FadlCard(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(title, style: FadlFonts.heading(size: 17)),
          ),
          const SizedBox(height: 4),
          if (builtIn != null)
            _option(context, id: builtIn, name: prayerL(context).bundledAdhan)
          else
            _option(context, id: null, name: prayerL(context).noFajrAdhan),
          for (final sound in imported)
            _option(context, id: sound.id, name: sound.name, sound: sound),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: busy ? null : onImport,
              icon: const Icon(Icons.file_upload_outlined),
              label: Text(
                kind == 'fajr'
                    ? prayerL(context).importFajr
                    : prayerL(context).importPhone,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required String? id,
    required String name,
    AdhanSound? sound,
  }) {
    final isSelected = selected == id;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(
        isSelected
            ? Icons.radio_button_checked_rounded
            : Icons.radio_button_unchecked_rounded,
        color: isSelected ? FadlColors.sage : null,
      ),
      title: Text(
        name,
        style: FadlFonts.ui(size: 14.5),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      selected: isSelected,
      onTap: () => onSelect(id),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (id != null)
            IconButton(
              tooltip: previewing == id
                  ? prayerL(context).stopPreview
                  : prayerL(context).preview,
              onPressed: () => onPreview(id),
              icon: Icon(
                previewing == id
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outline_rounded,
              ),
            ),
          if (sound != null)
            IconButton(
              tooltip: prayerL(context).delete,
              onPressed: () => onDelete(sound),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
    );
  }
}

class _BatteryCard extends StatelessWidget {
  const _BatteryCard({required this.exempt, required this.onOpen});
  final bool? exempt;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return FadlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                exempt == true
                    ? Icons.battery_full_rounded
                    : Icons.battery_alert_rounded,
                color: exempt == true ? FadlColors.sage : FadlColors.gold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  exempt == true
                      ? prayerL(context).batteryExempt
                      : prayerL(context).batteryWarning,
                  style: FadlFonts.ui(size: 14.5, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(prayerL(context).batteryAdvice, style: FadlFonts.ui(size: 13)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.settings_outlined),
            label: Text(prayerL(context).openBatterySettings),
          ),
        ],
      ),
    );
  }
}
