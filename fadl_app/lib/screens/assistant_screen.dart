import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/offline_quran_search.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/live_search.dart';
import 'hadith/hadith_card.dart';
import 'quran/mushaf_reader_screen.dart';

/// Quran assistant (stitch_ui/_13): chat over the Quran, hadith and athkar,
/// plus a direct search tab.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    super.key,
    this.initialQuery,
    this.openSearch = false,
  });
  final String? initialQuery;
  final bool openSearch;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _Message {
  _Message.user(this.text) : response = null, error = null, loading = false;
  _Message.bot() : text = null, response = null, error = null, loading = true;

  final String? text;
  Map<String, dynamic>? response;
  String? error;
  bool loading;
  bool get isUser => text != null;
}

class _AssistantScreenState extends State<AssistantScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.openSearch ? 1 : 0,
  );
  final _input = TextEditingController();
  final _chatScroll = ScrollController();
  final _messages = <_Message>[];
  List<Map<String, dynamic>> _topics = const [];

  // Direct search
  final _searchInput = TextEditingController();
  Future<Map<String, dynamic>>? _searchFuture;
  Map<String, dynamic>? _latestSearchData;

  @override
  void initState() {
    super.initState();
    if (Api.hasBackend) _loadTopics();
    final q = widget.initialQuery?.trim();
    if (q != null && q.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ask(question: q));
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _input.dispose();
    _chatScroll.dispose();
    _searchInput.dispose();
    super.dispose();
  }

  Future<void> _loadTopics() async {
    try {
      final res =
          await Api.instance.get('/assistant/topics') as Map<String, dynamic>;
      if (mounted) {
        setState(
          () => _topics = (res['topics'] as List).cast<Map<String, dynamic>>(),
        );
      }
    } on ApiException {
      // Topic chips are optional; free-text questions still work.
    }
  }

  Future<void> _ask({String? question, Map<String, dynamic>? topic}) async {
    final label = question ?? topic!['nameAr'] as String;
    if (label.trim().length < 2) return;
    FocusScope.of(context).unfocus();
    _input.clear();
    final bot = _Message.bot();
    setState(
      () => _messages
        ..add(_Message.user(label))
        ..add(bot),
    );
    _scrollToEnd();
    try {
      if (Api.hasBackend) {
        final res =
            await Api.instance.post(
                  '/assistant/ask',
                  topic != null
                      ? {'topic': topic['slug']}
                      : {'question': question},
                )
                as Map<String, dynamic>;
        bot.response = res;
      } else {
        bot.response = (await OfflineQuranSearch.load()).assistantResponse(
          label,
        );
      }
    } on ApiException catch (e) {
      bot.error = e.message;
    } on Exception catch (e) {
      if (Api.hasBackend) rethrow;
      bot.error = 'تعذّر تحميل مصادر البحث المحلية: $e';
    }
    if (!mounted) return;
    setState(() => bot.loading = false);
    _scrollToEnd();
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_chatScroll.hasClients) {
      _chatScroll.animateTo(
        _chatScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });

  Future<Map<String, dynamic>> _fetchSearch(String q) => Api.hasBackend
      ? Api.instance
            .get('/search', {'q': q, 'type': 'all', 'limit': 20})
            .then((v) => v as Map<String, dynamic>)
      : OfflineQuranSearch.load().then((local) => local.search(q));

  void _runSearch() {
    final q = _searchInput.text.trim();
    if (q.length < 2) return;
    setState(() => _searchFuture = _fetchSearch(q));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('المساعد القرآني'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: FadlColors.gold,
          labelColor: dark ? FadlColors.mint : FadlColors.primary,
          labelStyle: FadlFonts.ui(size: 14, weight: FontWeight.w700),
          unselectedLabelStyle: FadlFonts.ui(size: 14),
          tabs: const [
            Tab(
              icon: Icon(Icons.auto_awesome_rounded, size: 20),
              text: 'المساعد',
            ),
            Tab(
              icon: Icon(Icons.manage_search_rounded, size: 20),
              text: 'بحث مباشر',
            ),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [_chatTab(), _searchTab()]),
    );
  }

  // ─────────────────────────── Chat ───────────────────────────

  Widget _chatTab() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _chatScroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              if (_messages.isEmpty) _welcome(),
              for (final m in _messages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: m.isUser ? _UserBubble(m.text!) : _botMessage(m),
                ),
            ],
          ),
        ),
        _composer(),
      ],
    );
  }

  Widget _welcome() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadlCard(
          color: FadlColors.emerald,
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: FadlColors.goldLight,
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                Api.hasBackend
                    ? 'السلام عليكم، كيف أساعدك اليوم؟'
                    : 'ابحث في القرآن والأذكار المحفوظة',
                style: FadlFonts.heading(size: 18, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                Api.hasBackend
                    ? 'اسأل عن آية أو حديث أو موضوع، وستصلك الإجابة موثّقة بالمصادر.'
                    : OfflineQuranSearch.disclaimer,
                textAlign: TextAlign.center,
                style: FadlFonts.ui(size: 13, color: FadlColors.onEmerald),
              ),
            ],
          ),
        ),
        if (_topics.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'موضوعات مقترحة',
            style: FadlFonts.ui(
              size: 14,
              weight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            runSpacing: 8,
            children: [
              for (final t in _topics)
                PillChip(
                  label: t['nameAr'] as String,
                  selected: false,
                  onTap: () => _ask(topic: t),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _composer() {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          border: Border(
            top: BorderSide(color: FadlColors.emerald.withValues(alpha: 0.08)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_messages.isNotEmpty && _topics.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final t in _topics)
                      PillChip(
                        label: t['nameAr'] as String,
                        selected: false,
                        onTap: () => _ask(topic: t),
                      ),
                  ],
                ),
              ),
            if (_messages.isNotEmpty && _topics.isNotEmpty)
              const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (v) => _ask(question: v.trim()),
                    decoration: InputDecoration(
                      hintText: Api.hasBackend
                          ? 'ابحث عن آية، سورة، حديث، أو موضوع إسلامي...'
                          : 'ابحث نصيًا في القرآن والأذكار...',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: FadlColors.primary,
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => _ask(question: _input.text.trim()),
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _botMessage(_Message m) {
    final scheme = Theme.of(context).colorScheme;
    if (m.loading) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: FadlCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text(
                'جارٍ البحث في المصادر...',
                style: FadlFonts.ui(size: 13, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }
    if (m.error != null) {
      return FadlCard(
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: FadlColors.error),
            const SizedBox(width: 8),
            Expanded(child: Text(m.error!, style: FadlFonts.ui(size: 14))),
          ],
        ),
      );
    }
    final r = m.response!;
    final sources = r['sources'] as Map<String, dynamic>? ?? const {};
    final surahs = (sources['surahs'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final verses = (sources['verses'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final hadith = (sources['hadith'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final athkar = (sources['athkar'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final suggestions = (r['suggestions'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final ai = r['mode'] == 'ai';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadlCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    ai
                        ? Icons.auto_awesome_rounded
                        : Icons.library_books_outlined,
                    size: 18,
                    color: FadlColors.gold,
                  ),
                  const SizedBox(width: 6),
                  Badge2(
                    ai
                        ? 'الذكاء الاصطناعي • موثق'
                        : r['mode'] == 'offline-search'
                        ? 'بحث نصي محلي'
                        : 'نتائج من المصادر',
                    color: ai ? FadlColors.gold : FadlColors.sage,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SelectableText(
                r['answer'] as String? ?? '',
                style: FadlFonts.ui(size: 15, height: 1.7),
              ),
            ],
          ),
        ),
        if (surahs.isNotEmpty) ...[
          _sourceHeader(Icons.menu_book_rounded, 'السور المطابقة'),
          for (final surah in surahs)
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MushafReaderScreen(
                    initialPage: surah['startPage'] as int,
                  ),
                ),
              ),
              icon: const Icon(Icons.menu_book_rounded),
              label: Text('سورة ${surah['nameAr']} • فتح في المصحف'),
            ),
        ],
        if (verses.isNotEmpty) ...[
          _sourceHeader(Icons.menu_book_rounded, 'من القرآن الكريم'),
          for (final v in verses)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: VerseResultCard(verse: v),
            ),
        ],
        if (hadith.isNotEmpty) ...[
          _sourceHeader(Icons.format_quote_rounded, 'من السنة النبوية'),
          for (final h in hadith)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: HadithCard(hadith: h, maxLines: 6, showActions: true),
            ),
        ],
        if (athkar.isNotEmpty) ...[
          _sourceHeader(Icons.spa_outlined, 'من الأذكار والأدعية'),
          for (final a in athkar)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DhikrResultCard(dhikr: a),
            ),
        ],
        if ((r['disclaimer'] as String?)?.isNotEmpty ?? false)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    r['disclaimer'] as String,
                    style: FadlFonts.ui(
                      size: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'أسئلة مقترحة',
            style: FadlFonts.ui(
              size: 13,
              weight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            runSpacing: 8,
            children: [
              for (final s in suggestions)
                PillChip(
                  label: s['nameAr'] as String,
                  selected: false,
                  onTap: () => _ask(topic: s),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _sourceHeader(IconData icon, String title) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 18, color: FadlColors.gold),
        const SizedBox(width: 6),
        Text(
          title,
          style: FadlFonts.heading(
            size: 16,
            color: Theme.of(context).brightness == Brightness.dark
                ? FadlColors.darkText
                : FadlColors.primary,
          ),
        ),
      ],
    ),
  );

  // ─────────────────────────── Direct search ───────────────────────────

  Widget _searchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: LiveSearch<Map<String, dynamic>>(
            controller: _searchInput,
            minLength: 2,
            hintText: Api.hasBackend
                ? 'ابحث في السور والآيات والأحاديث والأذكار...'
                : 'ابحث في السور والآيات والأذكار المحفوظة...',
            onChanged: (q) => setState(() {
              _searchFuture = null;
              _latestSearchData = null;
            }),
            search: (q) async {
              final result = await _fetchSearch(q);
              _latestSearchData = result;
              final surahs = (result['surahs'] as List? ?? const [])
                  .cast<Map<String, dynamic>>();
              final verses =
                  ((result['verses'] as Map?)?['hits'] as List? ?? const [])
                      .cast<Map<String, dynamic>>();
              return [
                for (final s in surahs)
                  LiveSearchSuggestion<Map<String, dynamic>>({
                    'item': s,
                    'kind': 'surah',
                  }, 'سورة ${s['nameAr']}'),
                for (final v in verses)
                  LiveSearchSuggestion<Map<String, dynamic>>(
                    {'item': v, 'kind': 'verse'},
                    'سورة ${v['surahNameAr']} • ${arNum(v['number'])}',
                    subtitle: v['text'] as String?,
                  ),
              ];
            },
            onResults: (_) {
              if (_searchInput.text.trim().length >= 2 &&
                  _latestSearchData != null) {
                setState(
                  () => _searchFuture = Future.value(_latestSearchData!),
                );
              }
            },
            onSelected: (choice) {
              final item = choice['item'] as Map<String, dynamic>;
              final page =
                  (item['page'] as num?)?.toInt() ??
                  (item['startPage'] as num?)?.toInt() ??
                  1;
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MushafReaderScreen(
                    initialPage: page,
                    highlightAyahKey: choice['kind'] == 'verse'
                        ? item['key'] as String?
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
        if (!Api.hasBackend)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              OfflineQuranSearch.disclaimer,
              textAlign: TextAlign.center,
              style: FadlFonts.ui(
                size: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        Expanded(
          child: _searchFuture == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'ابحث بكلمة أو أكثر، والبحث لا يتأثر بالتشكيل.',
                      textAlign: TextAlign.center,
                      style: FadlFonts.ui(
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : FutureBuilder<Map<String, dynamic>>(
                  future: _searchFuture,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return ErrorCard(
                        message: '${snap.error}',
                        onRetry: _runSearch,
                      );
                    }
                    return _searchResults(snap.data!);
                  },
                ),
        ),
      ],
    );
  }

  Widget _searchResults(Map<String, dynamic> data) {
    final scheme = Theme.of(context).colorScheme;
    final surahs = (data['surahs'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final verseBlock = data['verses'] as Map<String, dynamic>? ?? const {};
    final verses = (verseBlock['hits'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final hadithBlock = data['hadith'] as Map<String, dynamic>? ?? const {};
    final hadith = (hadithBlock['results'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final athkar = (data['athkar'] as List? ?? const [])
        .cast<Map<String, dynamic>>();

    if (surahs.isEmpty && verses.isEmpty && hadith.isEmpty && athkar.isEmpty) {
      return Center(
        child: Text(
          'لا توجد نتائج',
          style: FadlFonts.ui(size: 15, color: scheme.onSurfaceVariant),
        ),
      );
    }
    String count(Object? total, int shown) => total is num && total > shown
        ? '${arNum(shown)} من ${arNum(total)}'
        : arNum(shown);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (surahs.isNotEmpty) ...[
          SectionTitle('السور'),
          for (final s in surahs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FadlCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MushafReaderScreen(
                      initialPage: (s['startPage'] as num?)?.toInt() ?? 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Badge2(arNum(s['id']), color: FadlColors.gold),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'سورة ${s['nameAr']}',
                        style: FadlFonts.heading(size: 16),
                      ),
                    ),
                    Text(
                      '${s['revelationTypeAr'] ?? ''} • ${arNum(s['ayahCount'] ?? 0)} آية',
                      style: FadlFonts.ui(
                        size: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Icon(Icons.chevron_left_rounded, color: scheme.outline),
                  ],
                ),
              ),
            ),
        ],
        if (verses.isNotEmpty) ...[
          SectionTitle(
            'الآيات',
            trailing: Text(
              count(verseBlock['total'], verses.length),
              style: FadlFonts.ui(size: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          for (final v in verses)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: VerseResultCard(verse: v),
            ),
        ],
        if (hadith.isNotEmpty) ...[
          SectionTitle(
            'الأحاديث',
            trailing: Text(
              count(hadithBlock['total'], hadith.length),
              style: FadlFonts.ui(size: 13, color: scheme.onSurfaceVariant),
            ),
          ),
          for (final h in hadith)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: HadithCard(hadith: h, maxLines: 6),
            ),
        ],
        if (athkar.isNotEmpty) ...[
          SectionTitle('الأذكار والأدعية'),
          for (final a in athkar)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DhikrResultCard(dhikr: a),
            ),
        ],
      ],
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.8,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: FadlColors.emerald,
          borderRadius: BorderRadiusDirectional.only(
            topStart: Radius.circular(18),
            topEnd: Radius.circular(18),
            bottomStart: Radius.circular(18),
            bottomEnd: Radius.circular(4),
          ),
        ),
        child: Text(text, style: FadlFonts.ui(size: 15, color: Colors.white)),
      ),
    ),
  );
}

/// Ayah result: surah + number, Uthmani text, collapsible muyassar tafsir,
/// copy / share / open-in-mushaf.
class VerseResultCard extends StatefulWidget {
  const VerseResultCard({super.key, required this.verse});
  final Map<String, dynamic> verse;

  @override
  State<VerseResultCard> createState() => _VerseResultCardState();
}

class _VerseResultCardState extends State<VerseResultCard> {
  bool _showTafsir = false;

  String get _ref =>
      'سورة ${widget.verse['surahNameAr']} - الآية ${arNum(widget.verse['number'] ?? '')}';
  String get _shareText => '﴿${widget.verse['text']}﴾\n[$_ref]\n— من تطبيق فضل';

  @override
  Widget build(BuildContext context) {
    final v = widget.verse;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tafsir = v['tafsir'] as String?;
    final accent = dark ? FadlColors.mint : FadlColors.sage;
    return FadlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _ref,
                  style: FadlFonts.ui(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              if (v['page'] != null)
                Badge2('ص ${arNum(v['page'])}', color: FadlColors.gold),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${v['text']} ${ayahMarker((v['number'] as num?)?.toInt() ?? 0)}',
            style: FadlFonts.scripture(size: 22, color: scheme.onSurface),
            textAlign: TextAlign.center,
          ),
          if (tafsir != null && tafsir.isNotEmpty) ...[
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _showTafsir = !_showTafsir),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 17,
                      color: FadlColors.gold,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'التفسير الميسر',
                        style: FadlFonts.ui(size: 13, weight: FontWeight.w700),
                      ),
                    ),
                    Icon(
                      _showTafsir
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            if (_showTafsir)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: dark
                      ? FadlColors.darkSurfaceHigh
                      : FadlColors.goldSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  tafsir,
                  style: FadlFonts.ui(size: 14, height: 1.7),
                ),
              ),
          ],
          const Divider(height: 18),
          Wrap(
            spacing: 4,
            children: [
              _SmallAction(
                icon: Icons.copy_rounded,
                label: 'نسخ',
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: _shareText));
                  if (context.mounted) showToast(context, 'تم نسخ الآية');
                },
              ),
              _SmallAction(
                icon: Icons.share_outlined,
                label: 'مشاركة',
                onTap: () =>
                    SharePlus.instance.share(ShareParams(text: _shareText)),
              ),
              _SmallAction(
                icon: Icons.chrome_reader_mode_outlined,
                label: 'فتح في المصحف',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MushafReaderScreen(
                      initialPage: (v['page'] as num?)?.toInt() ?? 1,
                      highlightAyahKey: v['key'] as String?,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Athkar / dua result with its reference, virtue and repeat count.
class DhikrResultCard extends StatelessWidget {
  const DhikrResultCard({super.key, required this.dhikr});
  final Map<String, dynamic> dhikr;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final category = dhikr['category'] as Map<String, dynamic>?;
    final repeat = (dhikr['repeat'] as num?)?.toInt() ?? 1;
    final text = dhikr['text'] as String? ?? '';
    final shareText =
        '$text${dhikr['reference'] != null ? '\n[${dhikr['reference']}]' : ''}\n— من تطبيق فضل';
    return FadlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (category != null)
                Expanded(
                  child: Text(
                    category['nameAr'] as String? ?? '',
                    style: FadlFonts.ui(
                      size: 13,
                      weight: FontWeight.w700,
                      color: dark ? FadlColors.mint : FadlColors.sage,
                    ),
                  ),
                )
              else
                const Spacer(),
              if (repeat > 1)
                Badge2('التكرار: ${arNum(repeat)}', color: FadlColors.gold),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            text,
            style: FadlFonts.scripture(
              size: 19,
              height: 1.9,
              color: scheme.onSurface,
            ),
          ),
          if ((dhikr['virtue'] as String?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 6),
            Text(
              'الفضل: ${dhikr['virtue']}',
              style: FadlFonts.ui(
                size: 13,
                color: scheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
          if ((dhikr['reference'] as String?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Text(
              dhikr['reference'] as String,
              style: FadlFonts.ui(
                size: 12,
                color: FadlColors.gold,
                weight: FontWeight.w600,
              ),
            ),
          ],
          const Divider(height: 18),
          Wrap(
            spacing: 4,
            children: [
              _SmallAction(
                icon: Icons.copy_rounded,
                label: 'نسخ',
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: shareText));
                  if (context.mounted) showToast(context, 'تم النسخ');
                },
              ),
              _SmallAction(
                icon: Icons.share_outlined,
                label: 'مشاركة',
                onTap: () =>
                    SharePlus.instance.share(ShareParams(text: shareText)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: TextButton.styleFrom(
      foregroundColor: Theme.of(context).brightness == Brightness.dark
          ? FadlColors.mint
          : FadlColors.sage,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      visualDensity: VisualDensity.compact,
    ),
    onPressed: onTap,
    icon: Icon(icon, size: 17),
    label: Text(
      label,
      style: FadlFonts.ui(size: 12.5, weight: FontWeight.w600),
    ),
  );
}
