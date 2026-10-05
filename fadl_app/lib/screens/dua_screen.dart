import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/offline_athkar.dart';
import '../core/quran_data.dart';
import '../core/theme.dart';
import '../l10n/prayer_labels.dart';
import '../widgets/common.dart';
import 'devotion/devotion_widgets.dart';

class _DuaData {
  _DuaData({
    required this.collections,
    required this.featured,
    required this.globalTotal,
    required this.myStats,
    required this.personal,
  });
  final List<Map<String, dynamic>> collections;
  final Map<String, dynamic>? featured;
  final int globalTotal;
  final Map<String, dynamic> myStats;
  final List<Map<String, dynamic>> personal;
}

/// Dua for the father / sadaqah jariyah (design _11).
class DuaScreen extends StatefulWidget {
  const DuaScreen({super.key});

  @override
  State<DuaScreen> createState() => _DuaScreenState();
}

class _DuaScreenState extends State<DuaScreen> {
  final _view = GlobalKey<AsyncViewState<_DuaData>>();
  final _newDua = TextEditingController();
  String _collection = 'parents';
  Future<Map<String, dynamic>>? _items;

  /// Local overrides after "آمين" and the per-card repeat counters.
  final Map<String, int> _amen = {};
  final Map<String, int> _reads = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _items = _loadCollection(_collection);
  }

  @override
  void dispose() {
    _newDua.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadCollection(String slug) async {
    if (Api.hasBackend) {
      return await Api.instance.get('/duas/collections/$slug')
          as Map<String, dynamic>;
    }
    final local = await OfflineAthkar.load();
    return local.duaCollection(
          slug,
          await QuranData.load(),
          amenCounts: await OfflineAthkarStore.amenCounts(),
        ) ??
        (throw StateError('Dua collection "$slug" not found'));
  }

  Future<_DuaData> _loadOffline() async {
    final local = await OfflineAthkar.load();
    final deceased = (await _loadCollection('deceased'))['items'] as List;
    final stats = await OfflineAthkarStore.dedicationStats();
    final reads = await OfflineAthkarStore.reads();
    _reads
      ..clear()
      ..addAll(reads);
    return _DuaData(
      collections: local.duaCollectionList(),
      featured: _featuredOf(deceased.cast<Map<String, dynamic>>()),
      globalTotal: stats['totalDedications'] as int,
      myStats: stats,
      personal: await OfflineAthkarStore.personalDuas(),
    );
  }

  // The featured dua is the first prophetic dua for the deceased.
  static Map<String, dynamic>? _featuredOf(
    List<Map<String, dynamic>> deceased,
  ) =>
      deceased.where((i) => i['kind'] == 'dhikr').firstOrNull ??
      deceased.firstOrNull;

  Future<_DuaData> _load() async {
    if (!Api.hasBackend) return _loadOffline();
    final res = await Future.wait([
      Api.instance.get('/duas/collections'),
      Api.instance.get('/duas/collections/deceased'),
      Api.instance.get('/stats/dedications'),
      Api.instance.get('/me/dedications/stats'),
      Api.instance.get('/me/duas'),
    ]);
    final deceased = List<Map<String, dynamic>>.from(
      (res[1] as Map)['items'] as List,
    );
    return _DuaData(
      collections: List<Map<String, dynamic>>.from(
        (res[0] as Map)['collections'] as List,
      ),
      featured: _featuredOf(deceased),
      globalTotal: ((res[2] as Map)['total'] as num?)?.toInt() ?? 0,
      myStats: Map<String, dynamic>.from(res[3] as Map),
      personal: List<Map<String, dynamic>>.from(
        (res[4] as Map)['duas'] as List,
      ),
    );
  }

  void _selectCollection(String slug) {
    setState(() {
      _collection = slug;
      _items = _loadCollection(slug);
    });
  }

  Future<void> _sayAmen(Map<String, dynamic> item) async {
    final key = item['amenKey'] as String;
    try {
      final res = Api.hasBackend
          ? await Api.instance.post('/duas/amen', {'targetKey': key}) as Map
          : await OfflineAthkarStore.sayAmen(key);
      HapticFeedback.lightImpact();
      setState(() => _amen[key] = (res['amenCount'] as num).toInt());
      if (mounted) {
        showToast(
          context,
          res['counted'] == true
              ? prayerL(context).duaAmenConfirmed
              : prayerL(context).duaAmenAlready,
        );
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  Future<void> _dedicateAndRefresh(
    String type, {
    int amount = 1,
    String? refKey,
  }) async {
    if (Api.hasBackend) {
      await dedicate(context, type, amount: amount, refKey: refKey);
    } else {
      await OfflineAthkarStore.dedicate(type, amount: amount);
      if (mounted) {
        showToast(
          context,
          prayerL(
            context,
          ).athkarDedicationRecorded(context.read<AppState>().dedicatee),
        );
      }
    }
    await _view.currentState?.reload();
  }

  Future<void> _savePersonal() async {
    final text = _newDua.text.trim();
    if (text.length < 2) {
      showToast(context, prayerL(context).duaEnterFirst);
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = Api.hasBackend
          ? await Api.instance.post('/me/duas', {'text': text}) as Map
          : await OfflineAthkarStore.savePersonalDua(text);
      _newDua.clear();
      if (mounted) {
        await _dedicateAndRefresh('DUA', refKey: 'custom:${saved['id']}');
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deletePersonal(Map<String, dynamic> dua) async {
    try {
      if (Api.hasBackend) {
        await Api.instance.delete('/me/duas/${dua['id']}');
      } else {
        await OfflineAthkarStore.deletePersonalDua(dua['id'] as String);
      }
      await _view.currentState?.reload();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  String _shareText(Map<String, dynamic> item) {
    final ref = item['reference'] as String?;
    return '${item['text']}${ref != null ? '\n[$ref]' : ''}\n— من تطبيق فضل';
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showToast(context, prayerL(context).duaCopied);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(prayerL(context).duaTitle)),
      body: AsyncView<_DuaData>(
        key: _view,
        load: _load,
        builder: (context, data, reload) => RefreshIndicator(
          onRefresh: () async {
            _selectCollection(_collection);
            await reload();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _hero(data),
              const SizedBox(height: 16),
              if (data.featured != null)
                _featuredCard(data.featured!, data.globalTotal),
              const SizedBox(height: 20),
              SectionTitle(prayerL(context).duaCollections),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final c in data.collections)
                      PillChip(
                        label: c['nameAr'] as String,
                        selected: _collection == c['slug'],
                        onTap: () => _selectCollection(c['slug'] as String),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _collectionItems(),
              const SizedBox(height: 12),
              _statsCard(data),
              const SizedBox(height: 16),
              _answerTimesCard(),
              const SizedBox(height: 16),
              _personalCard(data.personal),
            ],
          ),
        ),
      ),
    );
  }

  String _grouped(num count) => prayerL(context).localeName == 'en'
      ? NumberFormat('#,##0', 'en').format(count)
      : arInt(count);

  Widget _hero(_DuaData data) {
    final name = context.watch<AppState>().dedicatee;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [FadlColors.primary, FadlColors.emerald],
        ),
        border: Border.all(color: FadlColors.gold.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Badge2(
            prayerL(context).duaCharity,
            color: FadlColors.goldLight,
            background: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 12),
          Text(
            prayerL(context).duaMercy,
            textDirection: TextDirection.rtl,
            style: FadlFonts.ui(size: 14, color: FadlColors.onEmerald),
          ),
          Text(
            name,
            textAlign: TextAlign.center,
            style: FadlFonts.heading(size: 24, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'اللهم اجعل هذا العمل نوراً في قبره ورفعة لدرجته في الفردوس الأعلى',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: FadlFonts.ui(
              size: 13,
              color: FadlColors.onEmerald,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            Api.hasBackend
                ? prayerL(
                    context,
                  ).duaGlobalDedications(_grouped(data.globalTotal))
                : prayerL(
                    context,
                  ).duaLocalDedications(_grouped(data.globalTotal)),
            style: FadlFonts.ui(
              size: 13,
              weight: FontWeight.w700,
              color: FadlColors.goldLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _featuredCard(Map<String, dynamic> item, int globalTotal) {
    final scheme = Theme.of(context).colorScheme;
    return FadlCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: FadlColors.gold,
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  prayerL(context).duaFeatured,
                  style: FadlFonts.ui(
                    size: 13,
                    weight: FontWeight.w700,
                    color: FadlColors.sage,
                  ),
                ),
              ),
              if (item['reference'] != null)
                Badge2(item['reference'] as String),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item['text'] as String,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: FadlFonts.scripture(size: 22, color: scheme.onSurface),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAction(
                icon: Icons.copy_rounded,
                tooltip: prayerL(context).hadithCopy,
                onPressed: () => _copy(item['text'] as String),
              ),
              const SizedBox(width: 8),
              CircleAction(
                icon: Icons.share_outlined,
                tooltip: prayerL(context).share,
                onPressed: () => SharePlus.instance.share(
                  ShareParams(text: _shareText(item)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _dedicateAndRefresh(
                    'DUA',
                    refKey: item['amenKey'] as String?,
                  ),
                  icon: const Icon(Icons.volunteer_activism_rounded, size: 20),
                  label: Text(prayerL(context).duaDedicate),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _collectionItems() => FutureBuilder<Map<String, dynamic>>(
    future: _items,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snap.hasError) {
        return ErrorCard(
          message: '${snap.error}',
          onRetry: () => _selectCollection(_collection),
        );
      }
      final items = List<Map<String, dynamic>>.from(
        snap.data!['items'] as List,
      );
      return Column(
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _duaCard(items[i], i + 1),
            ),
        ],
      );
    },
  );

  Widget _duaCard(Map<String, dynamic> item, int index) {
    final scheme = Theme.of(context).colorScheme;
    final key = item['amenKey'] as String;
    final repeat = (item['repeat'] as num?)?.toInt() ?? 1;
    final reads = _reads[key] ?? 0;
    final amen = _amen[key] ?? (item['amenCount'] as num?)?.toInt() ?? 0;
    final isVerse = item['kind'] == 'verse';
    final virtue = item['virtue'] as String?;
    final reference = item['reference'] as String?;
    return FadlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isDark(context)
                    ? FadlColors.darkSurfaceHigh
                    : FadlColors.mint,
                child: Text(
                  prayerNumber(context, index),
                  style: FadlFonts.ui(
                    size: 12,
                    weight: FontWeight.w700,
                    color: FadlColors.sage,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isVerse
                      ? prayerL(context).duaVerseLabel
                      : prayerL(context).duaTraditionLabel,
                  style: FadlFonts.ui(
                    size: 12.5,
                    color: FadlColors.sage,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              if (reference != null)
                Flexible(child: Badge2(reference, color: FadlColors.gold)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              isVerse ? '﴿${item['text']}﴾' : item['text'] as String,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: FadlFonts.scripture(size: 20, color: scheme.onSurface),
            ),
          ),
          if (virtue != null) ...[
            const SizedBox(height: 8),
            Text(
              prayerL(context).duaVirtue(virtue),
              textDirection: TextDirection.rtl,
              style: FadlFonts.ui(
                size: 13,
                color: scheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ActionChip(
                avatar: const Icon(
                  Icons.front_hand_outlined,
                  size: 18,
                  color: FadlColors.sage,
                ),
                label: Text(
                  prayerL(context).duaAmenCount(prayerNumber(context, amen)),
                ),
                onPressed: () => _sayAmen(item),
              ),
              ActionChip(
                avatar: Icon(
                  reads >= repeat
                      ? Icons.check_circle_rounded
                      : Icons.repeat_rounded,
                  size: 18,
                  color: reads >= repeat ? FadlColors.sage : null,
                ),
                label: Text(
                  prayerL(context).duaReadCount(
                    prayerNumber(context, reads > repeat ? repeat : reads),
                    prayerNumber(context, repeat),
                  ),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  final next = reads >= repeat ? 0 : reads + 1;
                  setState(() => _reads[key] = next);
                  if (!Api.hasBackend) {
                    unawaited(OfflineAthkarStore.setRead(key, next));
                  }
                },
              ),
              IconButton(
                tooltip: prayerL(context).hadithCopy,
                icon: const Icon(Icons.copy_rounded, size: 20),
                onPressed: () => _copy(item['text'] as String),
              ),
              IconButton(
                tooltip: prayerL(context).share,
                icon: const Icon(Icons.share_outlined, size: 20),
                onPressed: () => SharePlus.instance.share(
                  ShareParams(text: _shareText(item)),
                ),
              ),
              TextButton.icon(
                onPressed: () => _dedicateAndRefresh('DUA', refKey: key),
                icon: const Icon(Icons.favorite_border_rounded, size: 18),
                label: Text(prayerL(context).duaDedicateParent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statsCard(_DuaData data) {
    final byType = Map<String, dynamic>.from(
      (data.myStats['byType'] as Map?) ?? const {},
    );
    int amount(String type) =>
        ((byType[type] as Map?)?['amount'] as num?)?.toInt() ?? 0;
    int count(String type) =>
        ((byType[type] as Map?)?['count'] as num?)?.toInt() ?? 0;
    return FadlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: FadlColors.sage),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  prayerL(context).duaStats,
                  style: FadlFonts.heading(
                    size: 17,
                    color: headingColor(context),
                  ),
                ),
              ),
              Badge2(
                prayerL(context).duaDedicationCount(
                  _grouped((data.myStats['totalDedications'] as num?) ?? 0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icon: Icons.menu_book_rounded,
                  value: _grouped(amount('KHATMA')),
                  label: prayerL(context).duaKhatmaStat,
                ),
              ),
              Expanded(
                child: StatTile(
                  icon: Icons.touch_app_outlined,
                  value: _grouped(amount('TASBEEH')),
                  label: prayerL(context).duaTasbeehStat,
                ),
              ),
              Expanded(
                child: StatTile(
                  icon: Icons.front_hand_outlined,
                  value: _grouped(count('DUA')),
                  label: prayerL(context).duaPrayerStat,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _answerTimesCard() {
    final state = context.watch<AppState>();
    final n = state.notifications;
    final enabled = n['qiyamEnabled'] == true && n['fridayHour'] == true;
    return FadlCard(
      color: isDark(context) ? FadlColors.darkSurface : FadlColors.goldSoft,
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active_outlined,
            color: FadlColors.gold,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prayerL(context).duaReminder,
                  style: FadlFonts.ui(size: 14.5, weight: FontWeight.w700),
                ),
                Text(
                  prayerL(context).duaReminderDescription,
                  textDirection: TextDirection.rtl,
                  style: FadlFonts.ui(
                    size: 12.5,
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (v) async {
              try {
                await state.updateNotifications({
                  'qiyamEnabled': v,
                  'fridayHour': v,
                });
                if (mounted) {
                  showToast(
                    context,
                    v
                        ? prayerL(context).duaReminderOn
                        : prayerL(context).duaReminderOff,
                  );
                }
              } on ApiException catch (e) {
                if (mounted) showToast(context, e.message);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _personalCard(List<Map<String, dynamic>> personal) {
    final scheme = Theme.of(context).colorScheme;
    return FadlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            prayerL(context).duaPersonalTitle,
            style: FadlFonts.heading(size: 17, color: headingColor(context)),
          ),
          Text(
            prayerL(context).duaPersonalDescription,
            style: FadlFonts.ui(size: 12.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _newDua,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            style: FadlFonts.scripture(size: 18, height: 1.7),
            decoration: InputDecoration(
              hintText: prayerL(context).duaPersonalHint,
            ),
          ),
          FilledButton.icon(
            onPressed: _saving ? null : _savePersonal,
            icon: const Icon(Icons.send_rounded),
            label: Text(prayerL(context).duaSaveDedicate),
          ),
          if (personal.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              prayerL(context).duaSaved,
              style: FadlFonts.ui(size: 14, weight: FontWeight.w700),
            ),
            for (final d in personal)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  d['text'] as String,
                  style: FadlFonts.scripture(size: 17, height: 1.7),
                ),
                subtitle: Text(
                  prayerNumber(
                    context,
                    (d['createdAt'] as String).substring(0, 10),
                  ),
                  style: FadlFonts.ui(size: 11.5),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: prayerL(context).share,
                      icon: const Icon(Icons.share_outlined, size: 20),
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(text: d['text'] as String),
                      ),
                    ),
                    IconButton(
                      tooltip: prayerL(context).duaDelete,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: FadlColors.error,
                      ),
                      onPressed: () => _deletePersonal(d),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
