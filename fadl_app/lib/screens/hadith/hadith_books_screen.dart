import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/offline_hadith.dart';
import '../../core/theme.dart';
import '../../l10n/prayer_labels.dart';
import '../../widgets/common.dart';
import '../../widgets/live_search.dart';
import 'hadith_book_screen.dart';
import 'hadith_card.dart';
import 'hadith_detail_screen.dart';

/// Hadith library: search, hadith of the day and the list of collections.
class HadithBooksScreen extends StatefulWidget {
  const HadithBooksScreen({super.key});

  @override
  State<HadithBooksScreen> createState() => _HadithBooksScreenState();
}

class _HadithBooksScreenState extends State<HadithBooksScreen> {
  static const _pageSize = 20;
  static const _groupOrder = ['الكتب التسعة', 'الأربعينيات', 'كتب أخرى'];

  final _searchCtrl = TextEditingController();
  late Future<List<dynamic>> _home = _loadHome();

  // Search state
  String _query = '';
  String? _bookFilter;
  final _results = <Map<String, dynamic>>[];
  int _total = 0;
  bool _searching = false;
  String? _searchError;
  int _searchGeneration = 0;

  Future<List<dynamic>> _loadHome() async {
    await OfflineHadith.instance.ready();
    if (!Api.hasBackend) {
      return [
        <String, dynamic>{'books': OfflineHadith.instance.availableBooks},
        null,
      ];
    }
    return Future.wait([
      Api.instance.get('/hadith/books'),
      Api.instance
          .get('/hadith/daily')
          .then<dynamic>((v) => v, onError: (_) => null),
    ]);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _search({
    bool more = false,
    String? query,
  }) async {
    final q = (query ?? _searchCtrl.text).trim();
    final generation = ++_searchGeneration;
    if (q.length < 2) {
      if (q.isEmpty) {
        setState(() => _query = '');
      } else {
        showToast(context, prayerL(context).hadithMinimumQuery);
      }
      return [];
    }
    if (more && _searching) return [];
    if (query == null && !more) FocusScope.of(context).unfocus();
    setState(() {
      _query = q;
      _searching = true;
      _searchError = null;
      if (!more) {
        _results.clear();
        _total = 0;
      }
    });
    try {
      final res = Api.hasBackend
          ? await Api.instance.get('/hadith/search', {
                  'q': q,
                  'book': _bookFilter,
                  'limit': _pageSize,
                  'offset': more ? _results.length : 0,
                })
                as Map<String, dynamic>
          : await OfflineHadith.instance.search(
              q,
              bookSlug: _bookFilter,
              limit: _pageSize,
              offset: more ? _results.length : 0,
            );
      if (!mounted || generation != _searchGeneration) return [];
      setState(() {
        _results.addAll((res['results'] as List).cast<Map<String, dynamic>>());
        _total = (res['total'] as num?)?.toInt() ?? _results.length;
      });
    } on Exception catch (e) {
      if (mounted && generation == _searchGeneration) {
        setState(() => _searchError = '$e');
      }
    } finally {
      if (mounted && generation == _searchGeneration) {
        setState(() => _searching = false);
      }
    }
    return _results;
  }

  void _selectBook(String? slug) {
    setState(() => _bookFilter = slug);
    if (_query.isNotEmpty) _search();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(prayerL(context).hadithLibraryTitle)),
      body: FutureBuilder<List<dynamic>>(
        future: _home,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ErrorCard(
              message: '${snap.error}',
              onRetry: () => setState(() => _home = _loadHome()),
            );
          }
          final books =
              ((snap.data![0] as Map<String, dynamic>)['books'] as List)
                  .cast<Map<String, dynamic>>();
          final daily = snap.data![1] as Map<String, dynamic>?;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _searchField(),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    PillChip(
                      label: prayerL(context).hadithAllBooks,
                      selected: _bookFilter == null,
                      onTap: () => _selectBook(null),
                    ),
                    for (final b in books)
                      PillChip(
                        label: b['nameAr'] as String,
                        selected: _bookFilter == b['slug'],
                        onTap: () => _selectBook(b['slug'] as String),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (!Api.hasBackend)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'نصوص الكتب: AhmedBaset Hadith JSON — https://github.com/AhmedBaset/hadith-json\nدرجات السنن الأربع: fawazahmed0 hadith-api — https://github.com/fawazahmed0/hadith-api',
                  ),
                ),
              if (_query.isNotEmpty)
                ..._searchResults()
              else
                ..._library(books, daily),
            ],
          );
        },
      ),
    );
  }

  Widget _searchField() {
    final fallback = prayerL(context).hadithUnit;
    return LiveSearch<Map<String, dynamic>>(
      controller: _searchCtrl,
      hintText: prayerL(context).hadithSearchHint,
      minLength: 2,
      onChanged: (q) {
        _searchGeneration++;
        setState(() {
          _query = q;
          _results.clear();
          _searching = false;
          _searchError = null;
        });
      },
      search: (q) async => [
        for (final h in await _search(query: q))
          LiveSearchSuggestion(
            h,
            h['book'] is Map
                ? (h['book'] as Map)['nameAr'] as String? ?? fallback
                : fallback,
            subtitle: h['textAr'] as String?,
          ),
      ],
      onSelected: (h) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => HadithDetailScreen(hadith: h)),
      ),
    );
  }

  List<Widget> _searchResults() {
    final scheme = Theme.of(context).colorScheme;
    return [
      SectionTitle(
        prayerL(context).hadithResults,
        trailing: _searching && _results.isEmpty
            ? null
            : Text(
                prayerL(
                  context,
                ).hadithResultCount(prayerNumber(context, _total)),
                style: FadlFonts.ui(size: 13, color: scheme.onSurfaceVariant),
              ),
      ),
      if (_searchError != null && _results.isEmpty)
        ErrorCard(message: _searchError!, onRetry: _search),
      if (!_searching && _searchError == null && _results.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            prayerL(context).hadithNoMatches,
            textAlign: TextAlign.center,
            style: FadlFonts.ui(color: scheme.onSurfaceVariant),
          ),
        ),
      for (final h in _results)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: HadithCard(hadith: h),
        ),
      if (_searching)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        )
      else if (_results.isNotEmpty && _results.length < _total)
        OutlinedButton.icon(
          onPressed: () => _search(more: true),
          icon: const Icon(Icons.expand_more_rounded),
          label: Text(prayerL(context).hadithLoadMore),
        ),
    ];
  }

  String _groupLabel(String group) {
    final l = prayerL(context);
    return switch (group) {
      'الكتب التسعة' => l.hadithNineBooks,
      'الأربعينيات' => l.hadithForties,
      'كتب أخرى' => l.hadithOtherBooks,
      _ => group,
    };
  }

  List<Widget> _library(
    List<Map<String, dynamic>> books,
    Map<String, dynamic>? daily,
  ) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final b in books) {
      if (_bookFilter != null && b['slug'] != _bookFilter) continue;
      groups
          .putIfAbsent(b['groupAr'] as String? ?? 'كتب أخرى', () => [])
          .add(b);
    }
    final ordered = [
      ..._groupOrder.where(groups.containsKey),
      ...groups.keys.where((g) => !_groupOrder.contains(g)),
    ];
    final hadith = daily?['hadith'] as Map<String, dynamic>?;
    return [
      if (hadith != null && _bookFilter == null) ...[
        _DailyHadith(hadith: hadith),
        const SizedBox(height: 8),
      ],
      for (final g in ordered) ...[
        SectionTitle(_groupLabel(g)),
        for (final b in groups[g]!)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BookTile(
              book: b,
              onChanged: () => setState(() => _home = _loadHome()),
            ),
          ),
      ],
    ];
  }
}

class _DailyHadith extends StatelessWidget {
  const _DailyHadith({required this.hadith});
  final Map<String, dynamic> hadith;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.wb_sunny_outlined,
              color: FadlColors.gold,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                prayerL(context).hadithOfDay,
                style: FadlFonts.heading(
                  size: 19,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? FadlColors.darkText
                      : FadlColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        HadithCard(hadith: hadith, maxLines: 6, showActions: true),
      ],
    );
  }
}

class _BookTile extends StatefulWidget {
  const _BookTile({required this.book, required this.onChanged});
  final Map<String, dynamic> book;
  final VoidCallback onChanged;

  @override
  State<_BookTile> createState() => _BookTileState();
}

class _BookTileState extends State<_BookTile> {
  bool _busy = false;
  int? _bytes;

  @override
  void initState() {
    super.initState();
    _refreshSize();
  }

  Future<void> _refreshSize() async {
    final bytes = await OfflineHadith.instance.size(
      widget.book['slug'] as String,
    );
    if (mounted) setState(() => _bytes = bytes);
  }

  Future<void> _download() async {
    final slug = widget.book['slug'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(prayerL(context).hadithDownloadTitle),
        content: Text(
          prayerL(
            context,
          ).hadithDownloadPrompt(widget.book['nameAr'] as String),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(prayerL(context).trackerCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(prayerL(context).hadithDownload),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await OfflineHadith.instance.download(slug, widget.book);
      await _refreshSize();
      widget.onChanged();
    } on Exception catch (error) {
      if (mounted) {
        showToast(
          context,
          prayerL(context).hadithDownloadError(error.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await OfflineHadith.instance.delete(widget.book['slug'] as String);
      await _refreshSize();
      widget.onChanged();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final downloaded = OfflineHadith.instance.isDownloaded(
      book['slug'] as String,
    );
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return FadlCard(
      padding: const EdgeInsets.all(14),
      onTap: !Api.hasBackend && !downloaded
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HadithBookScreen(
                  slug: book['slug'] as String,
                  nameAr: book['nameAr'] as String,
                ),
              ),
            ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: dark ? FadlColors.darkSurfaceHigh : FadlColors.goldSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: FadlColors.gold.withValues(alpha: 0.5)),
            ),
            child: Icon(
              Icons.menu_book_rounded,
              color: dark ? FadlColors.goldLight : FadlColors.gold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book['nameAr'] as String? ?? '',
                  style: FadlFonts.heading(size: 16),
                ),
                Text(
                  downloaded
                      ? prayerL(context).hadithDownloadedSize(
                          ((_bytes ?? 0) / 1048576).toStringAsFixed(1),
                        )
                      : prayerL(context).hadithNotDownloaded,
                  style: FadlFonts.ui(size: 12, color: scheme.onSurfaceVariant),
                ),
                if (book['authorAr'] != null)
                  Text(
                    book['authorAr'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FadlFonts.ui(
                      size: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (book['hadithCount'] != null)
            Column(
              children: [
                Text(
                  prayerNumber(context, book['hadithCount']),
                  style: FadlFonts.ui(
                    size: 15,
                    weight: FontWeight.w700,
                    color: dark ? FadlColors.mint : FadlColors.sage,
                  ),
                ),
                Text(
                  prayerL(context).hadithUnit,
                  style: FadlFonts.ui(size: 11, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          _busy
              ? const CircularProgressIndicator()
              : IconButton(
                  tooltip: downloaded
                      ? prayerL(context).hadithDeleteDownload
                      : prayerL(context).hadithDownloadBook,
                  onPressed: downloaded ? _delete : _download,
                  icon: Icon(
                    downloaded ? Icons.delete_outline : Icons.download_rounded,
                  ),
                ),
          Icon(Icons.chevron_left_rounded, color: scheme.outline),
        ],
      ),
    );
  }
}
