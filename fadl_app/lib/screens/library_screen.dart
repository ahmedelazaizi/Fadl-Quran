import 'package:flutter/material.dart';

import '../core/audio_store.dart';
import '../core/download_updates.dart';
import '../core/offline_hadith.dart';
import '../core/offline_tafsir.dart';
import '../core/offline_tajweed.dart';
import '../core/theme.dart';
import '../l10n/prayer_labels.dart';
import '../widgets/common.dart';
import '../widgets/live_search.dart';
import 'downloads_screen.dart';
import 'quran/audio_library_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryEntry {
  const _LibraryEntry(
    this.id,
    this.title,
    this.group,
    this.source,
    this.url,
    this.license,
    this.approxBytes,
    this.installed,
    this.bytes,
    this.download,
    this.remove, {
    this.secondaryUrl,
    this.bundled = false,
  });
  final String id, title, group, source, url, license;
  final int approxBytes, bytes;
  final bool installed;
  final Future<void> Function() download, remove;

  /// A second file the entry downloads (the hadith English translation).
  final String? secondaryUrl;

  /// Installed from a file shipped with the app: no online update check.
  final bool bundled;
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _tafsir = OfflineTafsir.instance;
  final _tajweed = OfflineTajweed.instance;
  final _hadith = OfflineHadith.instance;
  final _audio = AudioStore.instance;
  final _updates = DownloadUpdates.instance;
  late Future<List<_LibraryEntry>> _entries = _load();
  final Map<String, UpdateStatus> _statuses = {};
  final Set<String> _busy = {};
  String _query = '';
  bool _checking = false;

  Future<List<_LibraryEntry>> _load() async {
    await Future.wait([
      _tafsir.ready(),
      _tajweed.ready(),
      _hadith.ready(),
      _audio.ready(),
    ]);
    final entries = <_LibraryEntry>[
      for (final edition in offlineTafsirEditions)
        _LibraryEntry(
          'tafsir:${edition.slug}',
          edition.nameAr,
          'التفاسير',
          'alquran.cloud API',
          OfflineTafsir.sourceUrl(edition.slug),
          'نص من واجهة alquran.cloud؛ راجع شروط المصدر.',
          edition.approxBytes,
          _tafsir.isDownloaded(edition.slug),
          await _tafsir.size(edition.slug),
          () => _tafsir.download(edition.slug),
          () => _tafsir.delete(edition.slug),
        ),
      _LibraryEntry(
        'tajweed',
        'نص التجويد الملوّن',
        'نص التجويد الملوّن',
        tajweedSource,
        tajweedSourceUrl,
        'مواضع التجويد من cpfair/quran-tajweed بترخيص CC BY 4.0، على نص المصحف العثماني من Tanzil.net. مضمَّن في التطبيق ويعمل دون اتصال.',
        tajweedApproxBytes,
        _tajweed.isDownloaded,
        await _tajweed.size(),
        _tajweed.download,
        _tajweed.delete,
        bundled: true,
      ),
      for (final book in _hadith.availableBooks)
        _LibraryEntry(
          'hadith:${book['slug']}',
          book['nameAr'] as String,
          'كتب الحديث',
          'fawazahmed0/hadith-api',
          OfflineHadith.sourceUrl(book['slug'] as String)!,
          'النص العربي والدرجات والترجمة الإنجليزية من fawazahmed0/hadith-api، وهي ضمن الملكية العامة (Unlicense).',
          hadithApproxDownloadBytes[book['slug'] as String]!,
          _hadith.isDownloaded(book['slug'] as String),
          await _hadith.size(book['slug'] as String),
          () => _hadith.download(book['slug'] as String, book),
          () => _hadith.delete(book['slug'] as String),
          secondaryUrl: OfflineHadith.translationSourceUrl(
            book['slug'] as String,
          ),
        ),
    ];
    for (final entry in entries.where(
      (entry) => entry.installed && !entry.bundled,
    )) {
      final record = await _updates.recordFor(entry.id);
      if (record == null ||
          record.etag == null && record.lastModified == null) {
        _statuses[entry.id] = UpdateStatus.unknown;
      }
    }
    return entries;
  }

  void _reload() {
    if (mounted) {
      setState(() {
        _entries = _load();
      });
    }
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final entries = await _entries;
      for (final entry in entries.where(
        (entry) => entry.installed && !entry.bundled,
      )) {
        try {
          var status = await _updates.check(entry.id, entry.url);
          if (entry.secondaryUrl != null) {
            final secondary = await _updates.check(
              'translation:${entry.id.substring(7)}',
              entry.secondaryUrl!,
            );
            if (secondary == UpdateStatus.available) status = secondary;
            if (secondary == UpdateStatus.unknown &&
                status != UpdateStatus.available) {
              status = secondary;
            }
          }
          if (mounted) setState(() => _statuses[entry.id] = status);
        } catch (_) {
          if (mounted) {
            showToast(
              context,
              prayerL(context).libraryCheckFailed(entry.title),
            );
          }
        }
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _download(_LibraryEntry entry) async {
    if (!_busy.add(entry.id)) return;
    setState(() {});
    try {
      await entry.download();
      _statuses.remove(entry.id);
      _reload();
      if (mounted) {
        showToast(context, prayerL(context).libraryDownloaded(entry.title));
      }
    } catch (_) {
      if (mounted) {
        showToast(context, prayerL(context).libraryDownloadFailed);
      }
    } finally {
      _busy.remove(entry.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _remove(_LibraryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(prayerL(context).libraryDeleteConfirm(entry.title)),
        content: Text(prayerL(dialog).libraryRedownloadNotice),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(prayerL(dialog).libraryCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(prayerL(dialog).libraryDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await entry.remove();
      _statuses.remove(entry.id);
      _reload();
    } catch (_) {
      if (mounted) {
        showToast(context, prayerL(context).libraryDeleteFailed(entry.title));
      }
    }
  }

  void _about(_LibraryEntry entry) => showDialog<void>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: Text(prayerL(context).libraryAboutTitle(entry.title)),
      content: SelectableText(
        '${prayerL(context).librarySourceLabel(entry.source)}\n${entry.url}'
        '${entry.secondaryUrl == null ? '' : '\n${prayerL(context).libraryTranslationLabel(entry.secondaryUrl!)}'}\n${entry.license}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: Text(prayerL(dialog).libraryClose),
        ),
      ],
    ),
  );

  Widget _row(_LibraryEntry entry, {bool update = false}) {
    final busy = _busy.contains(entry.id);
    final status = _statuses[entry.id];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FadlCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.title,
              style: FadlFonts.ui(size: 16, weight: FontWeight.w700),
            ),
            Text(
              '${entry.source} • ${entry.installed ? prayerBytes(context, entry.bytes) : prayerL(context).libraryApproxSize(prayerBytes(context, entry.approxBytes))}',
              style: FadlFonts.ui(size: 12),
            ),
            if (entry.installed && !update && status == UpdateStatus.unknown)
              Text(prayerL(context).libraryUnknownUpdate),
            if (busy) const LinearProgressIndicator(),
            Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: () => _about(entry),
                  child: Text(prayerL(context).libraryAbout),
                ),
                if (entry.installed && !update)
                  TextButton(
                    onPressed: busy ? null : () => _remove(entry),
                    child: Text(prayerL(context).libraryDelete),
                  ),
                if (!entry.installed ||
                    update ||
                    status == UpdateStatus.unknown)
                  FilledButton.tonal(
                    onPressed: busy ? null : () => _download(entry),
                    child: Text(
                      busy
                          ? prayerL(context).libraryDownloading
                          : update
                          ? prayerL(context).libraryUpdate
                          : entry.installed
                          ? prayerL(context).libraryRedownload
                          : prayerL(context).libraryDownload,
                    ),
                  ),
              ],
            ),
            if (busy && entry.id == 'tajweed' && _tajweed.receivedBytes > 0)
              Text(
                prayerL(
                  context,
                ).libraryReceived(prayerBytes(context, _tajweed.receivedBytes)),
              ),
          ],
        ),
      ),
    );
  }

  String _groupLabel(String group) => switch (group) {
    'التفاسير' => prayerL(context).libraryTafsir,
    'نص التجويد الملوّن' => prayerL(context).libraryTajweed,
    'كتب الحديث' => prayerL(context).libraryHadithBooks,
    _ => group,
  };

  Widget _group(String title, List<_LibraryEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(_groupLabel(title)),
        for (final entry in entries) _row(entry),
      ],
    );
  }

  Widget _installed(List<_LibraryEntry> entries) {
    final updates = entries
        .where((entry) => _statuses[entry.id] == UpdateStatus.available)
        .toList();
    return RefreshIndicator(
      onRefresh: _check,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (updates.isNotEmpty) ...[
            SectionTitle(
              prayerL(context).libraryUpdates,
              trailing: TextButton(
                onPressed: _busy.isNotEmpty
                    ? null
                    : () async {
                        for (final entry in updates) {
                          await _download(entry);
                        }
                      },
                child: Text(prayerL(context).libraryUpdateAll),
              ),
            ),
            for (final entry in updates) _row(entry, update: true),
          ],
          for (final group in ['التفاسير', 'نص التجويد الملوّن', 'كتب الحديث'])
            _group(
              group,
              entries.where((entry) => entry.group == group).toList(),
            ),
          SectionTitle(prayerL(context).libraryRecitations),
          FutureBuilder<int>(
            future: _audio.totalSize(),
            builder: (context, snapshot) => FadlCard(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const DownloadsScreen(),
                ),
              ).then((_) => _reload()),
              child: ListTile(
                title: Text(prayerL(context).libraryRecitations),
                subtitle: Text(
                  prayerL(
                    context,
                  ).libraryUsedSpace(prayerBytes(context, snapshot.data ?? 0)),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: Text(prayerL(context).library),
        actions: [
          IconButton(
            tooltip: prayerL(context).libraryCheckUpdates,
            onPressed: _checking ? null : _check,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          tabs: [
            Tab(text: prayerL(context).librarySaved),
            Tab(text: prayerL(context).libraryDownloadTab),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: FutureBuilder<List<_LibraryEntry>>(
              future: _entries,
              builder: (context, snap) => LiveSearch<_LibraryEntry>(
                hintText: prayerL(context).librarySearch,
                onChanged: (query) => setState(() => _query = query),
                search: (query) async => [
                  for (final entry in snap.data ?? <_LibraryEntry>[])
                    if (matchesLiveSearch(entry.title, query) ||
                        matchesLiveSearch(entry.source, query))
                      LiveSearchSuggestion(
                        entry,
                        entry.title,
                        subtitle: entry.source,
                      ),
                ],
                onSelected: (entry) {
                  setState(() => _query = entry.title);
                  DefaultTabController.of(
                    context,
                  ).animateTo(entry.installed ? 0 : 1);
                },
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<_LibraryEntry>>(
              future: _entries,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorCard(
                    message: prayerL(context).libraryReadError,
                    onRetry: _reload,
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final visible = snapshot.data!
                    .where(
                      (entry) =>
                          _query.isEmpty ||
                          matchesLiveSearch(entry.title, _query) ||
                          matchesLiveSearch(entry.source, _query),
                    )
                    .toList();
                return TabBarView(
                  children: [
                    _installed(
                      visible.where((entry) => entry.installed).toList(),
                    ),
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final group in [
                          'التفاسير',
                          'نص التجويد الملوّن',
                          'كتب الحديث',
                        ])
                          _group(
                            group,
                            visible
                                .where(
                                  (entry) =>
                                      !entry.installed && entry.group == group,
                                )
                                .toList(),
                          ),
                        SectionTitle(prayerL(context).libraryRecitations),
                        FadlCard(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const AudioLibraryScreen(),
                            ),
                          ),
                          child: ListTile(
                            title: Text(prayerL(context).libraryReciterCatalog),
                            subtitle: Text(
                              prayerL(context).libraryChooseReciter,
                            ),
                            trailing: Icon(Icons.chevron_right_rounded),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
