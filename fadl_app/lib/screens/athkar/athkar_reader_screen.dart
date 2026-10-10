import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/athkar_repeats.dart';
import '../../l10n/prayer_labels.dart';
import '../../core/offline_athkar.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../devotion/devotion_widgets.dart';

/// Reads one athkar category card by card with a tap counter (design _6).
class AthkarReaderScreen extends StatefulWidget {
  const AthkarReaderScreen({
    super.key,
    required this.slug,
    required this.title,
    this.initialDhikrId,
  });
  final String slug;
  final String title;

  /// Opens directly on this dhikr (e.g. from search results).
  final int? initialDhikrId;

  @override
  State<AthkarReaderScreen> createState() => _AthkarReaderScreenState();
}

class _AthkarReaderScreenState extends State<AthkarReaderScreen> {
  List<Map<String, dynamic>> _items = [];
  final Map<int, int> _counts = {};
  final Map<int, Timer> _pending = {};
  PageController? _pages;
  int _page = 0;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // Flush unsynced counters immediately.
    for (final entry in _pending.entries.toList()) {
      entry.value.cancel();
      _sync(entry.key);
    }
    _pages?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<dynamic> res;
      if (Api.hasBackend) {
        res = await Future.wait([
          Api.instance.get('/athkar/categories/${widget.slug}'),
          Api.instance.get('/me/athkar/progress'),
        ]);
      } else {
        final local = await OfflineAthkar.load();
        res = [
          local.category(widget.slug) ?? const {'items': []},
          await OfflineAthkarStore.progress(local),
        ];
      }
      final items = List<Map<String, dynamic>>.from(
        (res[0] as Map)['items'] as List,
      );
      final saved = {
        for (final p
            in ((res[1] as Map)['items'] as List).cast<Map<String, dynamic>>())
          p['dhikrId'] as int: p['count'] as int,
      };
      final ids = items.map((i) => i['id'] as int).toSet();
      var start = items.indexWhere((i) => i['id'] == widget.initialDhikrId);
      if (start < 0) {
        // Resume at the first unfinished dhikr.
        start = items.indexWhere(
          (i) => (saved[i['id']] ?? 0) < (i['repeat'] as int),
        );
        if (start < 0) start = 0;
      }
      _pages?.dispose();
      setState(() {
        _items = items;
        _counts
          ..clear()
          ..addAll({
            for (final e in saved.entries)
              if (ids.contains(e.key)) e.key: e.value,
          });
        _page = start;
        _pages = PageController(initialPage: start);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  int _count(Map<String, dynamic> item) => _counts[item['id']] ?? 0;

  /// The dhikr whose round was just finished: it shows full (3 / 3) until
  /// the page moves on, then its counter starts again from zero. The day's
  /// count keeps growing, so the dhikr stays finished for today.
  int? _justFinished;

  bool _roundDone(Map<String, dynamic> item) => _justFinished == item['id'];

  int _shown(Map<String, dynamic> item) {
    final repeat = item['repeat'] as int;
    return _roundDone(item) ? repeat : _count(item) % repeat;
  }

  void _tap(Map<String, dynamic> item) {
    final id = item['id'] as int;
    final repeat = item['repeat'] as int;
    final current = _count(item);
    if (current >= OfflineAthkarStore.maxCount) return;
    final updated = current + 1;
    final finished = athkarRoundDone(updated, repeat);
    setState(() {
      _counts[id] = updated;
      _justFinished = finished ? id : null;
    });
    _scheduleSync(id);
    if (finished) {
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted && _items.isNotEmpty && _items[_page]['id'] == id) _next();
      });
    } else {
      HapticFeedback.lightImpact();
    }
  }

  /// Restarts the current round; finished rounds still count for today.
  void _reset(Map<String, dynamic> item) {
    final id = item['id'] as int;
    final count = _count(item);
    setState(() {
      _counts[id] = count - count % (item['repeat'] as int);
      _justFinished = null;
    });
    _scheduleSync(id);
  }

  void _scheduleSync(int id) {
    _pending[id]?.cancel();
    _pending[id] = Timer(const Duration(milliseconds: 700), () => _sync(id));
  }

  Future<void> _sync(int id) async {
    _pending.remove(id);
    if (!Api.hasBackend) {
      final count = _counts[id] ?? 0;
      await OfflineAthkarStore.setProgress(
        await OfflineAthkar.load(),
        id,
        count,
      );
      return;
    }
    try {
      await Api.instance.put('/me/athkar/progress', {
        'dhikrId': id,
        'count': _counts[id] ?? 0,
      });
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  Future<void> _dedicate() async {
    final amount = _completedItems > 0 ? _completedItems : 1;
    if (Api.hasBackend) {
      return dedicate(
        context,
        'ATHKAR',
        amount: amount,
        refKey: 'athkar:${widget.slug}',
      );
    }
    await OfflineAthkarStore.dedicate('ATHKAR', amount: amount);
    if (mounted) {
      showToast(
        context,
        prayerL(
          context,
        ).athkarDedicationRecorded(context.read<AppState>().dedicatee),
      );
    }
  }

  void _next() {
    _pages?.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  double get _overall {
    var total = 0;
    var done = 0;
    for (final i in _items) {
      final r = i['repeat'] as int;
      total += r;
      done += _count(i).clamp(0, r);
    }
    return total == 0 ? 0 : done / total;
  }

  int get _completedItems =>
      _items.where((i) => _count(i) >= (i['repeat'] as int)).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ErrorCard(message: '$_error', onRetry: _load)
          : _items.isEmpty
          ? ErrorCard(message: prayerL(context).athkarEmpty)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _page < _items.length
                                  ? prayerL(context).athkarPosition(
                                      prayerNumber(context, _page + 1),
                                      prayerNumber(context, _items.length),
                                    )
                                  : prayerL(context).athkarFinished,
                              style: FadlFonts.ui(
                                size: 13,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            prayerL(context).athkarCompletedCount(
                              prayerNumber(context, _completedItems),
                              prayerNumber(context, _items.length),
                            ),
                            style: FadlFonts.ui(
                              size: 13,
                              color: FadlColors.sage,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: _overall,
                          minHeight: 8,
                          color: FadlColors.sage,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHigh,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _items.length + 1,
                    onPageChanged: (p) => setState(() {
                      _page = p;
                      _justFinished = null;
                    }),
                    itemBuilder: (context, i) => i == _items.length
                        ? _finishPage()
                        : _dhikrPage(_items[i]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _dhikrPage(Map<String, dynamic> item) {
    final repeat = item['repeat'] as int;
    final count = _shown(item);
    final done = _roundDone(item);
    final scheme = Theme.of(context).colorScheme;
    final virtue = item['virtue'] as String?;
    final reference = item['reference'] as String?;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        FadlCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.stars_rounded,
                    color: FadlColors.gold,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: FadlFonts.ui(
                        size: 13,
                        color: FadlColors.sage,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  CircleAction(
                    icon: Icons.share_outlined,
                    tooltip: prayerL(context).share,
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        text:
                            '${item['text']}${reference != null ? '\n[$reference]' : ''}\n— من تطبيق فضل',
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAction(
                    icon: Icons.copy_rounded,
                    tooltip: prayerL(context).hadithCopy,
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: item['text'] as String),
                      );
                      if (mounted) {
                        showToast(context, prayerL(context).athkarCopied);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  item['text'] as String,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: FadlFonts.scripture(size: 22, color: scheme.onSurface),
                ),
              ),
              if (virtue != null) ...[
                const SizedBox(height: 14),
                Text(
                  prayerL(context).athkarVirtue,
                  style: FadlFonts.ui(
                    size: 13,
                    weight: FontWeight.w700,
                    color: FadlColors.gold,
                  ),
                ),
                Text(
                  virtue,
                  textDirection: TextDirection.rtl,
                  style: FadlFonts.ui(
                    size: 14,
                    height: 1.6,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (reference != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Badge2(reference),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: GestureDetector(
            onLongPress: () => _reset(item),
            // Solid, high-contrast counter: green while counting, gold when
            // a round is finished.
            child: Material(
              color: done ? FadlColors.gold : FadlColors.sage,
              elevation: 4,
              shadowColor: FadlColors.primary.withValues(alpha: 0.4),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _tap(item),
                child: SizedBox(
                  width: 168,
                  height: 168,
                  child: ProgressRing(
                    value: count / repeat,
                    size: 168,
                    stroke: 8,
                    color: done ? Colors.white : FadlColors.goldLight,
                    track: Colors.white.withValues(alpha: 0.25),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${prayerNumber(context, count)} / ${prayerNumber(context, repeat)}',
                          style: FadlFonts.heading(
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          done
                              ? prayerL(context).athkarRoundDone
                              : prayerL(context).athkarTapCount,
                          style: FadlFonts.ui(
                            size: 14,
                            color: Colors.white,
                            weight: FontWeight.w700,
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
        const SizedBox(height: 8),
        Text(
          prayerL(context).athkarLongPress,
          textAlign: TextAlign.center,
          style: FadlFonts.ui(size: 12, color: scheme.outline),
        ),
      ],
    );
  }

  Widget _finishPage() {
    final all = _completedItems == _items.length;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(
          all ? Icons.verified_rounded : Icons.hourglass_bottom_rounded,
          size: 72,
          color: FadlColors.gold,
        ),
        const SizedBox(height: 12),
        Text(
          all
              ? prayerL(context).athkarAccepted
              : prayerL(context).athkarRemaining(
                  prayerNumber(context, _items.length - _completedItems),
                ),
          textDirection: all ? TextDirection.rtl : null,
          textAlign: TextAlign.center,
          style: FadlFonts.heading(size: 24, color: headingColor(context)),
        ),
        const SizedBox(height: 8),
        Text(
          all
              ? prayerL(context).athkarFinishedToday(widget.title)
              : prayerL(context).athkarReturnToFinish,
          textAlign: TextAlign.center,
          style: FadlFonts.ui(
            size: 15,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: _dedicate,
          icon: const Icon(Icons.volunteer_activism_rounded),
          label: Text(prayerL(context).athkarDedicate),
        ),
        const SizedBox(height: 12),
        if (!all)
          OutlinedButton(
            onPressed: () {
              final first = _items.indexWhere(
                (i) => _count(i) < (i['repeat'] as int),
              );
              _pages?.animateToPage(
                first,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
              );
            },
            child: Text(prayerL(context).athkarFinishRemaining),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(prayerL(context).athkarBack),
        ),
      ],
    );
  }
}
