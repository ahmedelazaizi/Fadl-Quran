import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/local_user_data.dart';
import '../core/theme.dart';
import '../l10n/prayer_labels.dart';
import '../widgets/common.dart';
import 'devotion/devotion_widgets.dart';
import '../widgets/text_dialog.dart';

/// Electronic tasbeeh (design _7). Taps are counted locally and uploaded in
/// batches; each batch keeps its clientEventIds until the server accepts it,
/// so retries never double count. Without a backend, dhikrs and daily counts
/// live in [LocalUserData] on the device.
class TasbeehScreen extends StatefulWidget {
  const TasbeehScreen({super.key});

  @override
  State<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends State<TasbeehScreen> {
  Map<String, dynamic>? _summary;
  Object? _error;
  String? _selectedId;
  bool _vibration = true;
  bool _sound = false;

  /// Taps not yet put into a batch, per dhikr id.
  final Map<String, int> _pending = {};

  /// Batch being uploaded (kept intact for idempotent retries).
  List<Map<String, Object>> _outbox = [];
  bool _flushing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _flush());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flush();
    super.dispose();
  }

  LocalUserData get _local => LocalUserData.instance;

  int get _dailyGoal =>
      (_summary?['dailyGoal'] as int?) ??
      ((context.read<AppState>().settings['tasbeehDailyGoal'] as num?)
              ?.toInt() ??
          100);

  Future<void> _load() async {
    try {
      final s = Api.hasBackend
          ? await Api.instance.get('/me/tasbeeh') as Map<String, dynamic>
          : await _local.tasbeehSummary(dailyGoal: _dailyGoal);
      if (!mounted) return;
      setState(() {
        _summary = s;
        _error = null;
        final ids = _dhikrs.map((d) => d['id']).toList();
        if (_selectedId == null || !ids.contains(_selectedId)) {
          _selectedId = ids.isEmpty ? null : ids.first as String;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _flush() async {
    if (_flushing) return;
    if (!Api.hasBackend) return _flushLocal();
    if (_outbox.isEmpty) {
      if (_pending.isEmpty) return;
      _outbox = [
        for (final e in _pending.entries)
          {
            'dhikrId': e.key,
            'count': e.value,
            'clientEventId': randomEventId(),
          },
      ];
      _pending.clear();
    }
    _flushing = true;
    try {
      final res =
          await Api.instance.post('/me/tasbeeh/entries', {'entries': _outbox})
              as Map<String, dynamic>;
      _outbox = [];
      if (mounted) {
        setState(() => _summary = res['summary'] as Map<String, dynamic>);
      }
    } on ApiException catch (e) {
      // Unknown dhikr (deleted elsewhere): drop the batch instead of retrying forever.
      if (e.statusCode == 400) _outbox = [];
    } finally {
      _flushing = false;
    }
  }

  /// Saves pending taps on the device; they leave [_pending] only together
  /// with the refreshed summary so the counter never dips.
  Future<void> _flushLocal() async {
    if (_pending.isEmpty || _summary == null) return;
    final batch = Map<String, int>.of(_pending);
    final goal = _summary!['dailyGoal'] as int? ?? 100;
    _flushing = true;
    try {
      final s = await _local.addTasbeehCounts(batch, dailyGoal: goal);
      void apply() {
        for (final e in batch.entries) {
          final left = (_pending[e.key] ?? 0) - e.value;
          left > 0 ? _pending[e.key] = left : _pending.remove(e.key);
        }
        _summary = s;
      }

      mounted ? setState(apply) : apply();
    } finally {
      _flushing = false;
    }
  }

  List<Map<String, dynamic>> get _dhikrs => List<Map<String, dynamic>>.from(
    (_summary?['dhikrs'] as List?) ?? const [],
  );

  int _unsynced(String id) =>
      (_pending[id] ?? 0) +
      _outbox
          .where((e) => e['dhikrId'] == id)
          .fold<int>(0, (s, e) => s + (e['count'] as int));

  int _todayCount(Map<String, dynamic> d) =>
      (d['todayCount'] as int) + _unsynced(d['id'] as String);

  int get _todayTotal =>
      ((_summary?['todayTotal'] as int?) ?? 0) +
      _pending.values.fold<int>(0, (a, b) => a + b) +
      _outbox.fold<int>(0, (s, e) => s + (e['count'] as int));

  Map<String, dynamic>? get _current {
    for (final d in _dhikrs) {
      if (d['id'] == _selectedId) return d;
    }
    return null;
  }

  void _count() {
    final d = _current;
    if (d == null) return;
    final id = d['id'] as String;
    final target = d['target'] as int;
    setState(() => _pending[id] = (_pending[id] ?? 0) + 1);
    final completedRound = _todayCount(d) % target == 0;
    if (_vibration) {
      completedRound
          ? HapticFeedback.heavyImpact()
          : HapticFeedback.lightImpact();
    }
    if (_sound) SystemSound.play(SystemSoundType.click);
    if (completedRound) {
      showToast(
        context,
        prayerL(context).tasbeehRoundComplete(prayerNumber(context, target)),
      );
    }
  }

  Future<void> _reset() async {
    final d = _current;
    if (d == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(prayerL(context).tasbeehResetTitle),
        content: Text(
          prayerL(context).tasbeehResetConfirm(d['text'] as String),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(prayerL(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(prayerL(context).tasbeehReset),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _flush();
    try {
      if (Api.hasBackend) {
        await Api.instance.delete('/me/tasbeeh/today/${d['id']}');
      } else {
        await _local.resetTasbeehToday(d['id'] as String);
      }
      _pending.remove(d['id']);
      await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  /// Text and target entered for a new or edited dhikr; null when cancelled.
  Future<(String, int)?> _dhikrDialog({
    required String title,
    required String action,
    String initialText = '',
    int initialTarget = 33,
  }) async {
    final entered = await showTextDialog<(String, String)>(
      context: context,
      initialTexts: [initialText, '$initialTarget'],
      builder: (c, fields) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fields[0],
              autofocus: true,
              decoration: InputDecoration(
                labelText: prayerL(context).tasbeehText,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: fields[1],
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: prayerL(context).tasbeehTargetInput,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(prayerL(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, (fields[0].text, fields[1].text)),
            child: Text(action),
          ),
        ],
      ),
    );
    if (entered == null) return null;
    final value = entered.$1.trim();
    final goal = (int.tryParse(entered.$2) ?? 33).clamp(1, 10000);
    if (value.isEmpty) return null;
    return (value, goal);
  }

  Future<void> _addDhikr() async {
    final l = prayerL(context);
    final input = await _dhikrDialog(title: l.tasbeehAdd, action: l.tasbeehAdd);
    if (input == null) return;
    final (value, goal) = input;
    try {
      final created = Api.hasBackend
          ? await Api.instance.post('/me/tasbeeh/dhikrs', {
                  'text': value,
                  'target': goal,
                })
                as Map
          : await _local.addDhikr(value, goal);
      _selectedId = created['id'] as String;
      await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } on LocalDataException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  Future<void> _editDhikr(Map<String, dynamic> d) async {
    final input = await _dhikrDialog(
      title: prayerL(context).tasbeehEdit,
      action: prayerL(context).save,
      initialText: d['text'] as String,
      initialTarget: d['target'] as int,
    );
    if (input == null) return;
    final (value, goal) = input;
    await _flush();
    try {
      if (Api.hasBackend) {
        await Api.instance.patch('/me/tasbeeh/dhikrs/${d['id']}', {
          'text': value,
          'target': goal,
        });
      } else {
        await _local.updateDhikr(d['id'] as String, text: value, target: goal);
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } on LocalDataException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  Future<void> _dhikrOptions(Map<String, dynamic> d) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                d['text'] as String,
                textDirection: TextDirection.rtl,
                style: FadlFonts.scripture(size: 20, height: 1.5),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(prayerL(context).tasbeehEditTarget),
              onTap: () => Navigator.pop(c, 'edit'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: FadlColors.error,
              ),
              title: Text(prayerL(context).tasbeehDelete),
              onTap: () => Navigator.pop(c, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'edit') return _editDhikr(d);
    if (action != 'delete') return;
    await _flush();
    try {
      if (Api.hasBackend) {
        await Api.instance.delete('/me/tasbeeh/dhikrs/${d['id']}');
      } else {
        await _local.deleteDhikr(d['id'] as String);
      }
      _pending.remove(d['id']);
      await _load();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(prayerL(context).tasbeeh)),
      body: _summary == null
          ? (_error != null
                ? ErrorCard(
                    message: '$_error',
                    onRetry: () {
                      setState(() => _error = null);
                      _load();
                    },
                  )
                : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: () async {
                await _flush();
                await _load();
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  if (_current != null) ...[
                    _header(_current!),
                    const SizedBox(height: 24),
                    _counter(_current!),
                    const SizedBox(height: 20),
                    _toggles(),
                  ],
                  const SizedBox(height: 24),
                  SectionTitle(
                    prayerL(context).tasbeehChoose,
                    trailing: TextButton.icon(
                      onPressed: _addDhikr,
                      icon: const Icon(
                        Icons.add_circle_outline_rounded,
                        size: 20,
                      ),
                      label: Text(prayerL(context).tasbeehAdd),
                    ),
                  ),
                  _dhikrGrid(),
                  const SizedBox(height: 20),
                  _goalCard(),
                  const SizedBox(height: 20),
                  _dedicationCard(),
                ],
              ),
            ),
    );
  }

  Widget _header(Map<String, dynamic> d) {
    final target = d['target'] as int;
    final count = _todayCount(d);
    final round = count ~/ target + 1;
    final remaining = target - count % target;
    return FadlCard(
      color: isDark(context) ? FadlColors.darkSurface : FadlColors.goldSoft,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      child: Column(
        children: [
          Badge2(
            prayerL(context).tasbeehRoundRemaining(
              englishPrayerUi(context) ? '$round' : arOrdinal(round),
              prayerNumber(context, remaining),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            d['text'] as String,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: FadlFonts.scripture(
              size: 30,
              color: headingColor(context),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _counter(Map<String, dynamic> d) {
    final target = d['target'] as int;
    final count = _todayCount(d);
    final inRound = count % target;
    final display = count > 0 && inRound == 0 ? target : inRound;
    final dark = isDark(context);
    return Center(
      child: Semantics(
        button: true,
        label: prayerL(
          context,
        ).tasbeehCountSemantics(prayerNumber(context, display)),
        child: GestureDetector(
          onTap: _count,
          child: ProgressRing(
            value: display / target,
            size: 260,
            stroke: 14,
            color: FadlColors.sage,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dark ? FadlColors.darkSurface : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: FadlColors.emerald.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              // The circle has a fixed size; shrink large text to fit.
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        prayerL(context).tasbeehCurrentCount,
                        style: FadlFonts.ui(
                          size: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        prayerNumber(context, display),
                        style: FadlFonts.heading(
                          size: 64,
                          color: headingColor(context),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            prayerL(context).tasbeehTap,
                            style: FadlFonts.ui(
                              size: 13,
                              color: FadlColors.sage,
                              weight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.touch_app_outlined,
                            size: 18,
                            color: FadlColors.sage,
                          ),
                        ],
                      ),
                      Text(
                        prayerL(
                          context,
                        ).tasbeehToday(prayerNumber(context, count)),
                        style: FadlFonts.ui(
                          size: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggles() {
    Widget pill(String label, IconData icon, bool active, VoidCallback onTap) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ActionChip(
            avatar: Icon(
              icon,
              size: 18,
              color: active ? FadlColors.sage : null,
            ),
            label: Text(label),
            backgroundColor: active
                ? FadlColors.mint.withValues(alpha: isDark(context) ? 0.25 : 1)
                : null,
            onPressed: onTap,
          ),
        );
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        pill(
          prayerL(context).tasbeehReset,
          Icons.restart_alt_rounded,
          false,
          _reset,
        ),
        pill(
          _vibration
              ? prayerL(context).tasbeehVibrationOn
              : prayerL(context).tasbeehVibrationOff,
          Icons.vibration_rounded,
          _vibration,
          () => setState(() => _vibration = !_vibration),
        ),
        pill(
          _sound
              ? prayerL(context).tasbeehSoundOn
              : prayerL(context).tasbeehSoundOff,
          _sound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          _sound,
          () => setState(() => _sound = !_sound),
        ),
      ],
    );
  }

  Widget _dhikrGrid() {
    final dhikrs = _dhikrs;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: dhikrs.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 104,
      ),
      itemBuilder: (context, i) {
        final d = dhikrs[i];
        final selected = d['id'] == _selectedId;
        final fg = selected
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface;
        return FadlCard(
          color: selected ? FadlColors.primary : null,
          padding: const EdgeInsets.all(12),
          onTap: () => setState(() => _selectedId = d['id'] as String),
          child: GestureDetector(
            onLongPress: () => _dhikrOptions(d),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        d['text'] as String,
                        textDirection: TextDirection.rtl,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: FadlFonts.scripture(
                          size: 17,
                          color: fg,
                          height: 1.5,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: FadlColors.goldLight,
                        size: 20,
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  prayerL(context).tasbeehDhikrProgress(
                    prayerNumber(context, d['target'] as int),
                    prayerNumber(context, _todayCount(d)),
                  ),
                  style: FadlFonts.ui(
                    size: 12,
                    color: selected
                        ? FadlColors.onEmerald
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _goalCard() {
    final goal = (_summary!['dailyGoal'] as int?) ?? 100;
    final total = _todayTotal;
    final ratio = (total / goal).clamp(0.0, 1.0);
    final week = List<Map<String, dynamic>>.from(_summary!['week'] as List);
    final today = _summary!['date'] as String;
    final maxTotal = week.fold<int>(
      goal,
      (m, d) => (d['total'] as int) > m ? d['total'] as int : m,
    );
    final l = prayerL(context);
    final weekdays = [
      l.tasbeehMon,
      l.tasbeehTue,
      l.tasbeehWed,
      l.tasbeehThu,
      l.tasbeehFri,
      l.tasbeehSat,
      l.tasbeehSun,
    ];
    return FadlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: FadlColors.mint,
                child: Icon(Icons.flag_outlined, color: FadlColors.sage),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.tasbeehDailyGoal,
                      style: FadlFonts.heading(
                        size: 17,
                        color: headingColor(context),
                      ),
                    ),
                    Text(
                      l.tasbeehGoalProgress(
                        prayerNumber(context, total),
                        prayerNumber(context, goal),
                      ),
                      style: FadlFonts.ui(size: 13),
                    ),
                  ],
                ),
              ),
              Text(
                l.tasbeehPercent(prayerNumber(context, (ratio * 100).floor())),
                style: FadlFonts.heading(
                  size: 22,
                  color: headingColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              color: FadlColors.sage,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHigh,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.tasbeehThisWeek,
                  style: FadlFonts.ui(size: 13, weight: FontWeight.w600),
                ),
              ),
              Text(
                l.tasbeehStreak(
                  prayerNumber(context, _summary!['streakDays'] as int),
                ),
                style: FadlFonts.ui(
                  size: 12.5,
                  color: FadlColors.sage,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in week)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final isToday = d['date'] == today;
                        final value = isToday ? total : d['total'] as int;
                        final date = DateTime.parse(d['date'] as String);
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: 18,
                              height:
                                  8 + 72 * (value / maxTotal).clamp(0.0, 1.0),
                              decoration: BoxDecoration(
                                color: value == 0
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHigh
                                    : (isToday
                                          ? FadlColors.sage
                                          : FadlColors.sage.withValues(
                                              alpha: 0.5,
                                            )),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              weekdays[date.weekday - 1],
                              style: FadlFonts.ui(
                                size: 11,
                                weight: isToday
                                    ? FontWeight.w800
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dedicationCard() {
    final name = context.watch<AppState>().dedicatee;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FadlColors.emerald,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            prayerL(context).tasbeehCharity,
            style: FadlFonts.ui(size: 12, color: FadlColors.onEmerald),
          ),
          Text(
            prayerL(context).tasbeehDedication,
            style: FadlFonts.heading(size: 19, color: Colors.white),
          ),
          Text(
            '$name — رحمه الله وجعل هذا العمل نوراً في قبره ورفعة لدرجته',
            textDirection: TextDirection.rtl,
            style: FadlFonts.ui(
              size: 13,
              color: FadlColors.onEmerald,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: FadlColors.goldLight,
              foregroundColor: FadlColors.primary,
            ),
            onPressed: _todayTotal == 0
                ? () => showToast(context, prayerL(context).tasbeehCountFirst)
                : () async {
                    await _flush();
                    if (mounted) {
                      await dedicate(context, 'TASBEEH', amount: _todayTotal);
                    }
                  },
            icon: const Icon(Icons.volunteer_activism_rounded),
            label: Text(prayerL(context).tasbeehDedicateAction),
          ),
        ],
      ),
    );
  }
}
