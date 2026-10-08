import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/hajj_umrah.dart';
import '../core/theme.dart';
import '../l10n/prayer_labels.dart';
import '../widgets/common.dart';

/// Umrah and Hajj guides: an overview of the steps and a guided mode.
class HajjUmrahScreen extends StatelessWidget {
  const HajjUmrahScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = prayerL(context);
    return DefaultTabController(
      length: riteGuides.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.hajjUmrah),
          bottom: TabBar(
            tabs: [for (final guide in riteGuides) Tab(text: guide.title)],
          ),
        ),
        body: TabBarView(
          children: [for (final guide in riteGuides) _Overview(guide: guide)],
        ),
      ),
    );
  }
}

class _Overview extends StatefulWidget {
  const _Overview({required this.guide});
  final RiteGuide guide;

  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  RiteProgress? progress;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => progress = RiteProgress(prefs, widget.guide));
  }

  Future<void> _open({bool restart = false}) async {
    final current = progress!;
    if (restart) await current.restart();
    // Opening the guide counts as starting it, so the card offers "continue".
    await current.setStep(current.step);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => GuidedRiteScreen(progress: current),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = prayerL(context);
    final current = progress;
    if (current == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FadlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.riteDisclaimer, style: FadlFonts.ui(size: 13)),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _open,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  current.started
                      ? '${l.riteContinue} • ${l.riteStepOf(prayerNumber(context, current.step + 1), prayerNumber(context, widget.guide.steps.length))}'
                      : '${l.riteStart} ${widget.guide.title}',
                ),
              ),
              if (current.started)
                TextButton(
                  onPressed: () => _open(restart: true),
                  child: Text(l.riteRestart),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionTitle(l.riteSteps),
        for (final (index, step) in widget.guide.steps.indexed)
          Card(
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: FadlColors.mintSoft,
                foregroundColor: FadlColors.sage,
                child: Text(prayerNumber(context, index + 1)),
              ),
              title: Text(step.title, style: FadlFonts.ui(size: 15.5)),
              subtitle: Text(step.when, style: FadlFonts.ui(size: 12)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [_StepBody(step: step)],
            ),
          ),
      ],
    );
  }
}

/// Details and supplications of one step.
class _StepBody extends StatelessWidget {
  const _StepBody({required this.step});
  final RiteStep step;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final detail in step.details)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 7),
                child: Icon(Icons.circle, size: 7, color: FadlColors.sage),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  detail,
                  textDirection: TextDirection.rtl,
                  style: FadlFonts.ui(size: 14.5, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      if (step.duas.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          prayerL(context).riteSupplications,
          style: FadlFonts.ui(size: 14, weight: FontWeight.w700),
        ),
        for (final dua in step.duas)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FadlColors.mintSoft.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  dua.text,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: FadlFonts.quran(size: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  dua.source,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.center,
                  style: FadlFonts.ui(size: 12, color: FadlColors.sage),
                ),
              ],
            ),
          ),
      ],
    ],
  );
}

/// One step at a time with counters for rounds and pebbles.
class GuidedRiteScreen extends StatefulWidget {
  const GuidedRiteScreen({super.key, required this.progress});
  final RiteProgress progress;

  @override
  State<GuidedRiteScreen> createState() => _GuidedRiteScreenState();
}

class _GuidedRiteScreenState extends State<GuidedRiteScreen> {
  RiteProgress get progress => widget.progress;
  late int index = progress.step;

  Future<void> _go(int next) async {
    await progress.setStep(next);
    setState(() => index = next);
  }

  Future<void> _count(RiteStep step, int counter, int delta) async {
    final total = step.counters[counter].$2.total;
    final value = await progress.add(step, counter, delta);
    if (!mounted) return;
    setState(() {});
    if (delta > 0) {
      unawaited(
        value == total
            ? HapticFeedback.heavyImpact()
            : HapticFeedback.selectionClick(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = prayerL(context);
    final steps = progress.guide.steps;
    final step = steps[index];
    final last = index == steps.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(progress.guide.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (index + 1) / steps.length),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l.riteStepOf(
              prayerNumber(context, index + 1),
              prayerNumber(context, steps.length),
            ),
            style: FadlFonts.ui(size: 13, color: FadlColors.sage),
          ),
          Text(step.title, style: FadlFonts.heading(size: 22)),
          Text(step.when, style: FadlFonts.ui(size: 13)),
          const SizedBox(height: 12),
          for (final (counter, (label, spec)) in step.counters.indexed)
            _counterCard(step, counter, label, spec),
          _StepBody(step: step),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: index == 0 ? null : () => _go(index - 1),
                  child: Text(l.ritePrevious),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: last
                      ? () {
                          showToast(context, l.riteDone);
                          Navigator.pop(context);
                        }
                      : () => _go(index + 1),
                  child: Text(last ? l.riteDone : l.riteNext),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _counterCard(
    RiteStep step,
    int counter,
    String label,
    RiteCounter spec,
  ) {
    final l = prayerL(context);
    final count = progress.count(step, counter);
    final done = count >= spec.total;
    final round = done ? spec.total : count + 1;
    return FadlCard(
      child: Column(
        children: [
          Text(label, style: FadlFonts.ui(size: 15, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Semantics(
            button: true,
            label: l.riteRound(
              spec.unit,
              prayerNumber(context, count),
              prayerNumber(context, spec.total),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: done ? null : () => _count(step, counter, 1),
              child: Container(
                width: 132,
                height: 132,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? FadlColors.sage : FadlColors.mintSoft,
                ),
                child: done
                    ? const Icon(
                        Icons.check_rounded,
                        size: 56,
                        color: Colors.white,
                      )
                    : Text(
                        '${prayerNumber(context, count)} / ${prayerNumber(context, spec.total)}',
                        style: FadlFonts.heading(
                          size: 28,
                          color: FadlColors.sage,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            done
                ? l.riteCounterComplete
                : '${l.riteRound(spec.unit, prayerNumber(context, round), prayerNumber(context, spec.total))} • ${l.riteTapToCount}',
            style: FadlFonts.ui(size: 13),
          ),
          if (!done && spec.hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                spec.hint!(round),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: FadlFonts.ui(size: 13, color: FadlColors.sage),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: count == 0 ? null : () => _count(step, counter, -1),
                icon: const Icon(Icons.undo_rounded),
                label: Text(l.riteUndo),
              ),
              TextButton.icon(
                onPressed: count == 0
                    ? null
                    : () async {
                        await progress.reset(step, counter);
                        setState(() {});
                      },
                icon: const Icon(Icons.restart_alt_rounded),
                label: Text(l.riteReset),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
