import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/local_user_data.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'devotion/devotion_widgets.dart';
import 'quran/mushaf_reader_screen.dart';

class _KhatmaData {
  _KhatmaData(this.plan, this.presets);
  final Map<String, dynamic>? plan;
  final List<Map<String, dynamic>> presets;
}

/// Khatma plan and progress (design _9). Without a backend, plans, presets
/// and the reading log come from [LocalUserData] on the device.
class KhatmaScreen extends StatefulWidget {
  const KhatmaScreen({super.key});

  @override
  State<KhatmaScreen> createState() => _KhatmaScreenState();
}

class _KhatmaScreenState extends State<KhatmaScreen> {
  final _view = GlobalKey<AsyncViewState<_KhatmaData>>();
  Map<String, dynamic>? _plan; // latest plan (updated in place after progress)
  bool _busy = false;

  // Plan creation form.
  String _preset = '30-days';
  TimeOfDay? _reminder = const TimeOfDay(hour: 5, minute: 30);
  bool _dedicated = true;

  LocalUserData get _local => LocalUserData.instance;

  Future<_KhatmaData> _load() async {
    if (!Api.hasBackend) {
      final plans = await _local.khatmas(status: 'ACTIVE');
      _plan = plans.isEmpty ? null : plans.first;
      if (mounted) setState(() {});
      return _KhatmaData(_plan, LocalUserData.khatmaPresets);
    }
    final res = await Future.wait([
      Api.instance.get('/me/khatmas', {'status': 'ACTIVE'}),
      Api.instance.get('/khatma/presets'),
    ]);
    final plans = List<Map<String, dynamic>>.from(
      (res[0] as Map)['plans'] as List,
    );
    _plan = plans.isEmpty ? null : plans.first;
    if (mounted) setState(() {}); // refresh app bar actions
    return _KhatmaData(
      _plan,
      List<Map<String, dynamic>>.from((res[1] as Map)['presets'] as List),
    );
  }

  Future<void> _reload() async => _view.currentState?.reload();

  String _hm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } on LocalDataException catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() => _run(() async {
    final reminder = _reminder == null ? null : _hm(_reminder!);
    if (Api.hasBackend) {
      await Api.instance.post('/me/khatmas', {
        'preset': _preset,
        'reminderTime': reminder,
        'dedicated': _dedicated,
      });
    } else {
      await _local.createKhatma(
        preset: _preset,
        reminderTime: reminder,
        dedicated: _dedicated,
      );
    }
    if (mounted) showToast(context, 'بدأت ختمتك، أعانك الله وتقبّل منك');
    await _reload();
  });

  Future<void> _record(Map<String, Object> body) => _run(() async {
    final res = Api.hasBackend
        ? await Api.instance.post('/me/khatmas/${_plan!['id']}/progress', body)
              as Map<String, dynamic>
        : await _local.recordKhatma(
            _plan!['id'] as String,
            pages: body['pages'] as int?,
            toPage: body['toPage'] as int?,
          );
    HapticFeedback.lightImpact();
    setState(() => _plan = res['plan'] as Map<String, dynamic>);
    if (!mounted) return;
    if (res['completed'] == true) {
      await _celebrate(res['plan'] as Map<String, dynamic>);
      await _reload();
    } else {
      showToast(
        context,
        'سُجّلت ${arNum(res['recordedPages'] as int)} صفحة، بارك الله فيك',
      );
    }
  });

  Future<void> _celebrate(Map<String, dynamic> plan) async {
    final dedicated = plan['dedicated'] == true;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(
          Icons.celebration_rounded,
          color: FadlColors.gold,
          size: 48,
        ),
        title: Text(
          'ختمت القرآن الكريم',
          textAlign: TextAlign.center,
          style: FadlFonts.heading(size: 22),
        ),
        content: Text(
          dedicated
              ? 'مبارك! أتممت «${plan['title']}» وسُجّل ثوابها إهداءً لوالدك. تقبّل الله منك.'
              : 'مبارك! أتممت «${plan['title']}». تقبّل الله منك وجعله حجة لك.',
          textAlign: TextAlign.center,
        ),
        actions: [
          if (!dedicated)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(c);
                dedicate(
                  context,
                  'KHATMA',
                  amount: (plan['khatmaCount'] as int?) ?? 1,
                  refKey: 'khatma:${plan['id']}',
                );
              },
              icon: const Icon(Icons.volunteer_activism_rounded),
              label: const Text('أهدِ ثواب الختمة'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('الحمد لله'),
          ),
        ],
      ),
    );
  }

  Future<void> _toPageDialog() async {
    final ctrl = TextEditingController();
    final page = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('وصلت إلى صفحة...'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'آخر صفحة أتممتها (١ - ٦٠٤)',
            helperText:
                'الصفحة التالية في خطتك: ${arNum(_plan?['nextPage'] ?? 1)}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, int.tryParse(ctrl.text)),
            child: const Text('تسجيل'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (page == null) return;
    if (page < 1 || page > 604) {
      if (mounted) showToast(context, 'رقم الصفحة يجب أن يكون بين ١ و٦٠٤');
      return;
    }
    await _record({'toPage': page});
  }

  Future<void> _editReminder() async {
    final current = _plan!['reminderTime'] as String?;
    final initial = current == null
        ? const TimeOfDay(hour: 5, minute: 30)
        : TimeOfDay(
            hour: int.parse(current.split(':')[0]),
            minute: int.parse(current.split(':')[1]),
          );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'وقت تذكير الورد اليومي',
    );
    if (picked == null) return;
    await _patch({'reminderTime': _hm(picked)}, 'تم تحديث وقت التذكير');
  }

  Future<void> _patch(Map<String, Object?> body, String message) =>
      _run(() async {
        final updated = Api.hasBackend
            ? await Api.instance.patch('/me/khatmas/${_plan!['id']}', body)
                  as Map<String, dynamic>
            : await _local.patchKhatma(_plan!['id'] as String, body);
        setState(() => _plan = updated);
        if (mounted) showToast(context, message);
      });

  Future<void> _changePlan() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('تغيير الخطة'),
        content: const Text(
          'ستُؤرشف الختمة الحالية مع سجلها، ويمكنك بدء خطة جديدة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('أرشفة وبدء خطة جديدة'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      if (Api.hasBackend) {
        await Api.instance.patch('/me/khatmas/${_plan!['id']}', {
          'status': 'ARCHIVED',
        });
      } else {
        await _local.patchKhatma(_plan!['id'] as String, {
          'status': 'ARCHIVED',
        });
      }
      await _reload();
    });
  }

  void _showLogs() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, scroll) => AsyncView<List<Map<String, dynamic>>>(
          load: () async => Api.hasBackend
              ? List<Map<String, dynamic>>.from(
                  (await Api.instance.get('/me/khatmas/${_plan!['id']}/logs')
                          as Map)['days']
                      as List,
                )
              : _local.khatmaLogs(_plan!['id'] as String),
          builder: (context, days, _) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                'سجل القراءة',
                style: FadlFonts.heading(
                  size: 20,
                  color: headingColor(context),
                ),
              ),
              const SizedBox(height: 8),
              if (days.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('لم تُسجَّل قراءة بعد')),
                ),
              for (final d in days)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: FadlColors.mint,
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: FadlColors.sage,
                    ),
                  ),
                  title: Text(
                    '${arNum(d['pages'] as int)} صفحة',
                    style: FadlFonts.ui(size: 15, weight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${arNum(d['date'] as String)} • ${(d['entries'] as List).map((e) => '${arNum((e as Map)['fromPage'])}–${arNum(e['toPage'])}').join('، ')}',
                    style: FadlFonts.ui(size: 12.5),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ختمة القرآن'),
        actions: [
          if (_plan != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'logs':
                    _showLogs();
                  case 'reminder':
                    _editReminder();
                  case 'clear-reminder':
                    _patch({'reminderTime': null}, 'تم إيقاف التذكير');
                  case 'dedicate':
                    _patch({
                      'dedicated': !(_plan!['dedicated'] == true),
                    }, 'تم تحديث الإهداء');
                  default:
                    _changePlan();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'logs', child: Text('سجل القراءة')),
                const PopupMenuItem(
                  value: 'reminder',
                  child: Text('وقت التذكير'),
                ),
                if (_plan!['reminderTime'] != null)
                  const PopupMenuItem(
                    value: 'clear-reminder',
                    child: Text('إيقاف التذكير'),
                  ),
                PopupMenuItem(
                  value: 'dedicate',
                  child: Text(
                    _plan!['dedicated'] == true
                        ? 'إلغاء إهداء الختمة'
                        : 'إهداء ثواب الختمة لوالدي',
                  ),
                ),
                const PopupMenuItem(
                  value: 'change',
                  child: Text('تغيير الخطة'),
                ),
              ],
            ),
        ],
      ),
      body: AsyncView<_KhatmaData>(
        key: _view,
        load: _load,
        builder: (context, data, reload) => RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: _plan == null
                ? _presetsView(data.presets)
                : _planView(_plan!),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── No active plan ─────────────────────────

  List<Widget> _presetsView(List<Map<String, dynamic>> presets) {
    final scheme = Theme.of(context).colorScheme;
    return [
      FadlCard(
        color: isDark(context) ? FadlColors.darkSurface : FadlColors.goldSoft,
        child: Column(
          children: [
            const Icon(
              Icons.auto_stories_rounded,
              color: FadlColors.gold,
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              'ابدأ ختمة جديدة',
              style: FadlFonts.heading(size: 22, color: headingColor(context)),
            ),
            Text(
              '«خَيرُكُم مَن تَعَلَّمَ القُرآنَ وعَلَّمَه»',
              style: FadlFonts.scripture(size: 18, height: 1.6),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const SectionTitle('خيارات خطط الختم المتاحة'),
      for (final p in presets)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FadlCard(
            color: _preset == p['key']
                ? (isDark(context)
                      ? FadlColors.darkSurfaceHigh
                      : FadlColors.mintSoft)
                : null,
            onTap: () => setState(() => _preset = p['key'] as String),
            child: Row(
              children: [
                Icon(
                  _preset == p['key']
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: FadlColors.sage,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p['title']} (${arNum(p['durationDays'] as int)} يوماً)',
                        style: FadlFonts.heading(
                          size: 16,
                          color: headingColor(context),
                        ),
                      ),
                      Text(
                        '${arNum(p['pagesPerDay'] as int)} صفحة يومياً'
                        '${(p['khatmaCount'] as int) > 1 ? ' • ${arNum(p['khatmaCount'] as int)} ختمات' : ''}',
                        style: FadlFonts.ui(
                          size: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Badge2('${arNum(p['pagesPerPrayer'] as int)} صفحات / صلاة'),
              ],
            ),
          ),
        ),
      const SizedBox(height: 8),
      FadlCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            SwitchListTile(
              secondary: const Icon(
                Icons.notifications_active_outlined,
                color: FadlColors.sage,
              ),
              title: const Text('تنبيه الورد اليومي'),
              subtitle: Text(
                _reminder == null
                    ? 'متوقف'
                    : 'يومياً الساعة ${hm12(_hm(_reminder!))}',
              ),
              value: _reminder != null,
              onChanged: (v) => setState(
                () =>
                    _reminder = v ? const TimeOfDay(hour: 5, minute: 30) : null,
              ),
            ),
            if (_reminder != null)
              ListTile(
                leading: const Icon(
                  Icons.schedule_rounded,
                  color: FadlColors.sage,
                ),
                title: const Text('تغيير وقت التنبيه'),
                trailing: Text(hm12(_hm(_reminder!))),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _reminder!,
                  );
                  if (t != null) setState(() => _reminder = t);
                },
              ),
            SwitchListTile(
              secondary: const Icon(
                Icons.volunteer_activism_outlined,
                color: FadlColors.gold,
              ),
              title: const Text('إهداء ثواب الختمة لوالدي'),
              subtitle: const Text('يُسجَّل الإهداء تلقائياً عند الإتمام'),
              value: _dedicated,
              onChanged: (v) => setState(() => _dedicated = v),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _busy ? null : _create,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('ابدأ الختمة'),
      ),
    ];
  }

  // ───────────────────────── Active plan ─────────────────────────

  List<Widget> _planView(Map<String, dynamic> p) {
    final scheme = Theme.of(context).colorScheme;
    final today = p['today'] as Map<String, dynamic>;
    final position = p['position'] as Map<String, dynamic>?;
    final todayDone = today['done'] == true;
    final remainingToday = today['remaining'] as int;
    return [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: FadlColors.emerald,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'أنت في طريقك لختم القرآن',
                        style: FadlFonts.ui(
                          size: 12.5,
                          color: FadlColors.onEmerald,
                        ),
                      ),
                      Text(
                        p['title'] as String,
                        style: FadlFonts.heading(size: 20, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p['overdue'] == true
                            ? 'انتهت مدة الخطة، أكمل ما تبقى'
                            : 'متبقي ${arNum(p['daysLeft'] as int)} يوماً • اليوم ${arNum(p['dayNumber'] as int)} من ${arNum(p['durationDays'] as int)}',
                        style: FadlFonts.ui(
                          size: 13,
                          color: FadlColors.goldLight,
                        ),
                      ),
                      if ((p['khatmaCount'] as int) > 1)
                        Text(
                          'الختمة ${arOrdinal(p['currentKhatma'] as int)} من ${arNum(p['khatmaCount'] as int)}',
                          style: FadlFonts.ui(
                            size: 12.5,
                            color: FadlColors.onEmerald,
                          ),
                        ),
                    ],
                  ),
                ),
                ProgressRing(
                  value: (p['percent'] as int) / 100,
                  size: 104,
                  stroke: 10,
                  color: FadlColors.goldLight,
                  track: Colors.white.withValues(alpha: 0.15),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${arNum(p['percent'] as int)}٪',
                        style: FadlFonts.heading(size: 22, color: Colors.white),
                      ),
                      Text(
                        'نسبة الإنجاز',
                        style: FadlFonts.ui(
                          size: 10.5,
                          color: FadlColors.onEmerald,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 28),
            Row(
              children: [
                Expanded(
                  child: _whiteStat(
                    'الصفحات المقروءة',
                    '${arNum(p['pagesRead'] as int)} / ${arNum(p['totalPages'] as int)}',
                  ),
                ),
                Expanded(
                  child: _whiteStat(
                    'المتبقي للإتمام',
                    '${arNum(p['remainingPages'] as int)} صفحة (${arNum(p['remainingJuz'].toString())} جزء)',
                  ),
                ),
              ],
            ),
            if (position != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: FadlColors.goldLight,
                    foregroundColor: FadlColors.primary,
                  ),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MushafReaderScreen(
                          initialPage: position['page'] as int,
                          highlightAyahKey: position['ayahKey'] as String?,
                        ),
                      ),
                    );
                    if (mounted) _reload();
                  },
                  icon: const Icon(Icons.menu_book_rounded),
                  label: Text(
                    'متابعة القراءة (صفحة ${arNum(position['page'] as int)})',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      FadlCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  todayDone
                      ? Icons.check_circle_rounded
                      : Icons.calendar_month_rounded,
                  color: todayDone ? FadlColors.sage : FadlColors.gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الورد اليومي',
                    style: FadlFonts.heading(
                      size: 17,
                      color: headingColor(context),
                    ),
                  ),
                ),
                if (todayDone) const Badge2('مكتمل'),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              todayDone
                  ? 'أكملت ورد اليوم بحمد الله (${arNum(today['read'] as int)} / ${arNum(today['target'] as int)} صفحة)'
                  : 'المطلوب اليوم: ${arNum(today['target'] as int)} صفحة • قرأت ${arNum(today['read'] as int)} • المتبقي ${arNum(remainingToday)}',
              style: FadlFonts.ui(size: 14, height: 1.6),
            ),
            Text(
              'بمعدل ${arNum(today['perPrayer'] as int)} صفحات بعد كل صلاة',
              style: FadlFonts.ui(size: 12.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: (today['target'] as int) == 0
                    ? 1
                    : ((today['read'] as int) / (today['target'] as int)).clamp(
                        0.0,
                        1.0,
                      ),
                minHeight: 8,
                color: FadlColors.sage,
                backgroundColor: scheme.surfaceContainerHigh,
              ),
            ),
            if (position != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: FadlColors.gold,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'الموضع التالي: سورة ${position['surahNameAr']} • الجزء ${arNum(position['juz'] as int)}',
                    style: FadlFonts.ui(size: 13),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      const SectionTitle('تسجيل القراءة'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _quick('+١ صفحة', () => _record({'pages': 1})),
          _quick('+٥ صفحات', () => _record({'pages': 5})),
          if (remainingToday > 0)
            _quick(
              '+${arNum(remainingToday)} (ورد اليوم)',
              () => _record({'pages': remainingToday}),
            ),
        ],
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _busy ? null : _toPageDialog,
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('وصلت إلى صفحة...'),
      ),
      const SizedBox(height: 16),
      FadlCard(
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.history_rounded,
                color: FadlColors.sage,
              ),
              title: const Text('سجل القراءة'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: _showLogs,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.notifications_active_outlined,
                color: FadlColors.sage,
              ),
              title: const Text('تنبيه الورد اليومي'),
              subtitle: Text(
                p['reminderTime'] == null
                    ? 'متوقف'
                    : 'يومياً الساعة ${hm12(p['reminderTime'] as String)}',
              ),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: _editReminder,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.tune_rounded, color: FadlColors.sage),
              title: const Text('تغيير الخطة'),
              trailing: const Icon(Icons.chevron_left_rounded),
              onTap: _changePlan,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (p['dedicated'] == true)
        FadlCard(
          color: isDark(context) ? FadlColors.darkSurface : FadlColors.goldSoft,
          child: Row(
            children: [
              const Icon(
                Icons.volunteer_activism_rounded,
                color: FadlColors.gold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ثواب هذه الختمة مُهدى لوالدك، ويُسجَّل عند الإتمام بإذن الله',
                  style: FadlFonts.ui(size: 13.5, height: 1.6),
                ),
              ),
            ],
          ),
        )
      else
        const DedicationBanner(type: 'READING', label: 'إهداء ثواب القراءة'),
    ];
  }

  Widget _whiteStat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: FadlFonts.ui(size: 12, color: FadlColors.onEmerald)),
      Text(
        value,
        style: FadlFonts.ui(
          size: 15,
          weight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    ],
  );

  Widget _quick(String label, VoidCallback onTap) => ActionChip(
    avatar: const Icon(Icons.add_rounded, size: 18, color: FadlColors.sage),
    label: Text(label),
    onPressed: _busy ? null : onTap,
  );
}
