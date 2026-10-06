import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/local_notifications.dart';
import '../../core/quran_data.dart';
import '../../core/quran_learning.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

class QuranLearningScreen extends StatefulWidget {
  const QuranLearningScreen({super.key});

  @override
  State<QuranLearningScreen> createState() => _QuranLearningScreenState();
}

class _QuranLearningScreenState extends State<QuranLearningScreen> {
  late final Future<void> _ready = _load();
  final _pageController = TextEditingController(text: '1');
  late QuranQuizGenerator _generator;
  late QuranReviewStore _store;
  QuranQuizMode _mode = QuranQuizMode.hideNextAyah;
  QuranQuiz? _quiz;
  List<QuizAyah> _order = [];
  int _page = 1;
  bool _revealed = false;
  bool _saving = false;
  bool _rated = false;

  Future<void> _load() async {
    final quran = await QuranData.load();
    final preferences = await SharedPreferences.getInstance();
    _generator = QuranQuizGenerator(quran);
    _store = QuranReviewStore(preferences)..load();
    _newQuiz();
  }

  void _newQuiz() {
    _quiz = _generator.generate(_page, _mode);
    _order = _mode == QuranQuizMode.orderAyahs ? _quiz!.shuffled(Random()) : [];
    _revealed = false;
    _rated = false;
  }

  void _selectPage(int page) {
    if (page < 1 || page > 604) {
      _pageController.text = '$_page';
      return;
    }
    setState(() {
      _page = page;
      _pageController.text = '$page';
      _newQuiz();
    });
  }

  Future<void> _rate(int quality) async {
    if (_saving || _rated) return;
    final quiz = _quiz;
    final state = context.read<AppState>();
    setState(() => _saving = true);
    try {
      await _store.record(_page, quality, DateTime.now());
      // The new due date can add or drop an upcoming review reminder.
      if (state.notifications['quranReviewTime'] != null) {
        unawaited(LocalNotifications.instance.reschedule(state));
      }
      if (mounted) {
        setState(() {
          _saving = false;
          if (identical(_quiz, quiz)) _rated = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.reviewSaveError),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppLocalizations.of(context)!.quizTitle)),
    body: FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(AppLocalizations.of(context)!.quizLoadError),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return _content(context);
      },
    ),
  );

  Widget _content(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    String n(Object? number) =>
        Localizations.localeOf(context).languageCode == 'ar'
        ? arNum(number ?? 0)
        : '$number';
    final review = _store.review(_page);
    final dueCount = _store.dueCount(DateTime.now());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.reviewsDue(n(dueCount)), style: FadlFonts.ui(size: 16)),
        const SizedBox(height: 12),
        Row(
          children: [
            IconButton(
              tooltip: l.previousPage,
              onPressed: _page > 1 ? () => _selectPage(_page - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: TextField(
                controller: _pageController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.center,
                decoration: InputDecoration(labelText: l.quizPageLabel),
                onSubmitted: (text) => _selectPage(int.tryParse(text) ?? _page),
              ),
            ),
            IconButton(
              tooltip: l.nextPage,
              onPressed: _page < 604 ? () => _selectPage(_page + 1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (review != null)
          Text(
            review.isDue(DateTime.now())
                ? l.pageDue
                : l.nextReview(
                    '${n(review.due.toLocal().day)}/${n(review.due.toLocal().month)}',
                    n(review.intervalDays),
                  ),
            style: FadlFonts.ui(size: 14),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<QuranQuizMode>(
          initialValue: _mode,
          decoration: InputDecoration(labelText: l.quizType),
          items: [
            DropdownMenuItem(
              value: QuranQuizMode.hideNextAyah,
              child: Text(l.completeNextVerse),
            ),
            DropdownMenuItem(
              value: QuranQuizMode.maskedWords,
              child: Text(l.hiddenWords),
            ),
            DropdownMenuItem(
              value: QuranQuizMode.orderAyahs,
              child: Text(l.orderVerses),
            ),
          ],
          onChanged: (mode) {
            if (mode == null) return;
            setState(() {
              _mode = mode;
              _newQuiz();
            });
          },
        ),
        const SizedBox(height: 20),
        if (_mode == QuranQuizMode.orderAyahs) _orderQuiz() else _textQuiz(),
        const SizedBox(height: 16),
        if (_revealed) ...[
          Text(l.rateRecall, style: FadlFonts.ui(size: 15)),
          if (_rated) Text(l.reviewSaved),
          Wrap(
            spacing: 6,
            children: [
              for (var rating = 0; rating <= 5; rating++)
                OutlinedButton(
                  onPressed: _saving || _rated ? null : () => _rate(rating),
                  child: Text(n(rating)),
                ),
            ],
          ),
        ],
        TextButton.icon(
          onPressed: () => setState(_newQuiz),
          icon: const Icon(Icons.refresh),
          label: Text(l.newQuiz),
        ),
      ],
    );
  }

  Widget _ayahText(String text) => SelectableText(
    text,
    textDirection: TextDirection.rtl,
    style: FadlFonts.quran(size: 25),
  );

  Widget _textQuiz() {
    final l = AppLocalizations.of(context)!;
    final quiz = _quiz!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ayahText(quiz.prompt),
        const SizedBox(height: 12),
        if (!_revealed)
          FilledButton(
            onPressed: () => setState(() => _revealed = true),
            child: Text(l.showAnswer),
          )
        else ...[
          Text(
            l.answer,
            style: FadlFonts.ui(size: 16, weight: FontWeight.bold),
          ),
          _ayahText(quiz.answer),
        ],
      ],
    );
  }

  Widget _orderQuiz() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        AppLocalizations.of(context)!.dragVerses,
        style: FadlFonts.ui(size: 16),
      ),
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _order.length,
        onReorder: (oldIndex, newIndex) => setState(() {
          if (newIndex > oldIndex) newIndex--;
          _order.insert(newIndex, _order.removeAt(oldIndex));
        }),
        itemBuilder: (context, index) => Card(
          key: ValueKey(_order[index].key),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _ayahText(_order[index].text),
          ),
        ),
      ),
      if (!_revealed)
        FilledButton(
          onPressed: () => setState(() => _revealed = true),
          child: Text(AppLocalizations.of(context)!.checkOrder),
        )
      else ...[
        Text(
          _quiz!.isCorrectOrder(_order.map((ayah) => ayah.key).toList())
              ? AppLocalizations.of(context)!.correctOrder
              : AppLocalizations.of(context)!.actualOrder,
          style: FadlFonts.ui(size: 16, weight: FontWeight.bold),
        ),
        for (final ayah in _quiz!.ayahs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _ayahText(ayah.text),
          ),
      ],
    ],
  );
}
