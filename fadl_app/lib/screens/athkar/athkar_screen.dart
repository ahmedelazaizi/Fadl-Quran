import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../l10n/prayer_labels.dart';
import '../../core/offline_athkar.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/live_search.dart';
import '../devotion/devotion_widgets.dart';
import 'athkar_reader_screen.dart';

/// Icon per featured category slug (design _6).
IconData athkarIcon(String slug) => switch (slug) {
  'morning' => Icons.wb_twilight_rounded,
  'evening' => Icons.nightlight_round,
  'after-prayer' => Icons.mosque_outlined,
  'sleep' => Icons.bedtime_outlined,
  'waking' => Icons.alarm_on_rounded,
  'travel' => Icons.flight_takeoff_rounded,
  'distress' || 'grief' => Icons.favorite_border_rounded,
  'istighfar' => Icons.water_drop_outlined,
  'tasbih' => Icons.touch_app_outlined,
  'adhan' => Icons.campaign_outlined,
  'ruqyah-quran' || 'ruqyah-sunnah' => Icons.shield_outlined,
  _ => Icons.auto_stories_outlined,
};

class _AthkarData {
  _AthkarData(this.featured, this.all, this.progress);
  final List<Map<String, dynamic>> featured;
  final List<Map<String, dynamic>> all;
  final Map<String, Map<String, dynamic>> progress; // slug → progress
}

class AthkarScreen extends StatefulWidget {
  const AthkarScreen({super.key});

  @override
  State<AthkarScreen> createState() => _AthkarScreenState();
}

class _AthkarScreenState extends State<AthkarScreen> {
  final _search = TextEditingController();
  String _query = '';
  Future<List<Map<String, dynamic>>>? _results;
  String? _selected; // null = all
  int _reload = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<_AthkarData> _load() async {
    final List<dynamic> res;
    if (Api.hasBackend) {
      res = await Future.wait([
        Api.instance.get('/athkar/categories', {'featured': 'true'}),
        Api.instance.get('/athkar/categories'),
        Api.instance.get('/me/athkar/progress'),
      ]);
    } else {
      final local = await OfflineAthkar.load();
      res = [
        {'categories': local.categories(featured: true)},
        {'categories': local.categories()},
        await OfflineAthkarStore.progress(local),
      ];
    }
    List<Map<String, dynamic>> cats(dynamic r) =>
        List<Map<String, dynamic>>.from((r as Map)['categories'] as List);
    final progress = <String, Map<String, dynamic>>{
      for (final c
          in ((res[2] as Map)['categories'] as List)
              .cast<Map<String, dynamic>>())
        c['slug'] as String: c,
    };
    return _AthkarData(cats(res[0]), cats(res[1]), progress);
  }

  Future<List<Map<String, dynamic>>> _searchAthkar(String q) async {
    if (!Api.hasBackend) {
      return (await OfflineAthkar.load()).search(q, limit: 30);
    }
    final r = await Api.instance.get('/athkar/search', {'q': q, 'limit': 30});
    return List<Map<String, dynamic>>.from((r as Map)['results'] as List);
  }

  void _onSearch(String value) => setState(() {
    _query = value;
    _results = null;
  });

  Future<void> _open(String slug, String title, {int? dhikrId}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AthkarReaderScreen(
          slug: slug,
          title: title,
          initialDhikrId: dhikrId,
        ),
      ),
    );
    if (mounted) setState(() => _reload++); // refresh progress
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(prayerL(context).athkar)),
      body: AsyncView<_AthkarData>(
        reloadToken: _reload,
        load: _load,
        builder: (context, data, reload) => RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              LiveSearch<Map<String, dynamic>>(
                controller: _search,
                hintText: prayerL(context).athkarSearchHint,
                minLength: 2,
                onChanged: _onSearch,
                search: (q) async {
                  final found = await _searchAthkar(q);
                  return [
                    for (final c in data.all)
                      if (matchesLiveSearch(c['nameAr'] as String, q))
                        LiveSearchSuggestion<Map<String, dynamic>>({
                          'category': c,
                        }, c['nameAr'] as String),
                    for (final r in found)
                      LiveSearchSuggestion<Map<String, dynamic>>(
                        r,
                        (r['category'] as Map)['nameAr'] as String,
                        subtitle: r['text'] as String,
                      ),
                  ];
                },
                onResults: (items) => setState(
                  () => _results = Future.value([
                    for (final item in items)
                      if (item.value['id'] != null) item.value,
                  ]),
                ),
                onSelected: (item) {
                  final cat = item['category'] as Map;
                  _open(
                    cat['slug'] as String,
                    cat['nameAr'] as String,
                    dhikrId: item['id'] as int?,
                  );
                },
              ),
              const SizedBox(height: 12),
              if (_query.length >= 2) _searchResults() else ..._content(data),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchResults() => FutureBuilder<List<Map<String, dynamic>>>(
    future: _results,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snap.hasError) return ErrorCard(message: '${snap.error}');
      final results = snap.data ?? const [];
      if (results.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            prayerL(context).athkarNoResults(_query),
            textAlign: TextAlign.center,
            style: FadlFonts.ui(size: 15),
          ),
        );
      }
      return Column(
        children: [
          for (final r in results)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FadlCard(
                onTap: () {
                  final cat = r['category'] as Map;
                  _open(
                    cat['slug'] as String,
                    cat['nameAr'] as String,
                    dhikrId: r['id'] as int,
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Badge2((r['category'] as Map)['nameAr'] as String),
                    const SizedBox(height: 8),
                    Text(
                      r['text'] as String,
                      textDirection: TextDirection.rtl,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: FadlFonts.scripture(size: 18, height: 1.8),
                    ),
                    if ((r['repeat'] as int) > 1)
                      Text(
                        prayerL(context).athkarRepeat(
                          prayerNumber(context, r['repeat'] as int),
                        ),
                        style: FadlFonts.ui(
                          size: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );

  List<Widget> _content(_AthkarData data) {
    final featured = _selected == null
        ? data.featured
        : data.featured.where((c) => c['slug'] == _selected).toList();
    final others = data.all.where((c) => c['featured'] != true).toList();
    return [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            PillChip(
              label: prayerL(context).athkarAll,
              selected: _selected == null,
              onTap: () => setState(() => _selected = null),
            ),
            for (final c in data.featured)
              PillChip(
                label: c['nameAr'] as String,
                selected: _selected == c['slug'],
                onTap: () => setState(() => _selected = c['slug'] as String),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      if (data.featured.isNotEmpty) _progressCard(data),
      const SizedBox(height: 20),
      SectionTitle(
        prayerL(context).athkarChapters,
        trailing: Text(
          prayerL(
            context,
          ).athkarCategoryCount(prayerNumber(context, featured.length)),
          style: FadlFonts.ui(size: 12),
        ),
      ),
      for (final c in featured)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _categoryCard(c, data.progress[c['slug']]),
        ),
      const SizedBox(height: 8),
      const DedicationBanner(type: 'ATHKAR'),
      if (_selected == null && others.isNotEmpty) ...[
        const SizedBox(height: 20),
        SectionTitle(
          prayerL(context).athkarAllChapters,
          trailing: Text(
            prayerL(
              context,
            ).athkarOtherCount(prayerNumber(context, others.length)),
            style: FadlFonts.ui(size: 12),
          ),
        ),
        FadlCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < others.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  title: Text(
                    others[i]['nameAr'] as String,
                    style: FadlFonts.ui(size: 14.5, weight: FontWeight.w600),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        prayerNumber(context, others[i]['count'] as int),
                        style: FadlFonts.ui(size: 12),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  onTap: () => _open(
                    others[i]['slug'] as String,
                    others[i]['nameAr'] as String,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ];
  }

  Widget _progressCard(_AthkarData data) {
    final Map<String, dynamic>? target = _selected != null
        ? data.progress[_selected]
        // "All": continue with the first featured category that is not complete yet.
        : data.featured
              .map((c) => data.progress[c['slug']])
              .firstWhere(
                (p) => p != null && p['status'] != 'COMPLETED',
                orElse: () => data.progress[data.featured.first['slug']],
              );
    final title =
        (target?['nameAr'] as String?) ?? prayerL(context).athkarDailyWird;
    final done = (target?['completed'] as int?) ?? 0;
    final total = (target?['total'] as int?) ?? 0;
    final ratio = total == 0 ? 0.0 : done / total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FadlColors.emerald,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.circle,
                      size: 8,
                      color: FadlColors.goldLight,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      prayerL(context).athkarActiveWird,
                      style: FadlFonts.ui(
                        size: 12,
                        color: FadlColors.onEmerald,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: FadlFonts.heading(size: 22, color: Colors.white),
                ),
                Text(
                  prayerL(context).athkarDailyCompleted(
                    prayerNumber(context, done),
                    prayerNumber(context, total),
                  ),
                  style: FadlFonts.ui(size: 13, color: FadlColors.onEmerald),
                ),
                const SizedBox(height: 12),
                if (target != null)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: FadlColors.sage,
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: () => _open(target['slug'] as String, title),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: Text(
                      done == 0
                          ? prayerL(context).athkarStart
                          : prayerL(context).athkarContinue,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ProgressRing(
            value: ratio,
            size: 92,
            stroke: 9,
            color: FadlColors.mint,
            track: Colors.white.withValues(alpha: 0.15),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  prayerL(
                    context,
                  ).athkarPercent(prayerNumber(context, (ratio * 100).floor())),
                  style: FadlFonts.heading(size: 20, color: Colors.white),
                ),
                Text(
                  prayerL(context).athkarComplete,
                  style: FadlFonts.ui(size: 11, color: FadlColors.onEmerald),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryCard(Map<String, dynamic> c, Map<String, dynamic>? p) {
    final status = p?['status'] as String? ?? 'NOT_STARTED';
    final dark = isDark(context);
    final badge = switch (status) {
      'COMPLETED' => Badge2(
        prayerL(context).athkarComplete,
        color: FadlColors.sage,
        background: FadlColors.mint,
      ),
      'PARTIAL' => Badge2(
        prayerL(context).athkarPartial(
          prayerNumber(context, p!['completed'] as int),
          prayerNumber(context, p['total'] as int),
        ),
        color: FadlColors.sage,
        background: FadlColors.mintSoft,
      ),
      _ => Badge2(
        prayerL(context).athkarNotStarted,
        color: Theme.of(context).colorScheme.outline,
      ),
    };
    return FadlCard(
      onTap: () => _open(c['slug'] as String, c['nameAr'] as String),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: dark ? FadlColors.darkSurfaceHigh : FadlColors.mintSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              athkarIcon(c['slug'] as String),
              color: dark ? FadlColors.mint : FadlColors.sage,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c['nameAr'] as String,
                  style: FadlFonts.heading(
                    size: 17,
                    color: headingColor(context),
                  ),
                ),
                Text(
                  prayerL(
                    context,
                  ).athkarEntryCount(prayerNumber(context, c['count'] as int)),
                  style: FadlFonts.ui(
                    size: 12.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                badge,
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
