import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio_store.dart';
import '../../core/auto_download.dart';
import '../../core/quran_storage.dart';
import '../../core/reciters.dart';
import '../../core/theme.dart';
import '../../l10n/prayer_labels.dart';
import '../../widgets/common.dart';

/// Searchable reciter list with favourites first; returns the chosen id.
Future<String?> showReciterPicker(BuildContext context, String? selectedId) {
  unawaited(ReciterCatalog.instance.load());
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => _ReciterPicker(selectedId: selectedId),
  );
}

class _ReciterPicker extends StatefulWidget {
  const _ReciterPicker({required this.selectedId});
  final String? selectedId;

  @override
  State<_ReciterPicker> createState() => _ReciterPickerState();
}

class _ReciterPickerState extends State<_ReciterPicker> {
  final catalog = ReciterCatalog.instance;
  String query = '';

  @override
  Widget build(BuildContext context) {
    final l = prayerL(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                l.chooseReciterTitle,
                style: FadlFonts.heading(size: 18),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: l.reciterSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
                onChanged: (text) => setState(() => query = text),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListenableBuilder(
                listenable: catalog,
                builder: (context, _) {
                  final shown = [
                    for (final reciter in catalog.ordered())
                      if (matchesReciterSearch(reciter, query)) reciter,
                  ];
                  return ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, index) => _row(shown[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> reciter) {
    final l = prayerL(context);
    final id = reciter['id'] as String;
    final favorite = catalog.isFavorite(id);
    final selected = id == widget.selectedId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected
            ? FadlColors.sage.withValues(alpha: 0.25)
            : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: Text(
            reciter['nameAr'] as String,
            style: FadlFonts.ui(size: 15.5, weight: FontWeight.w600),
          ),
          subtitle: Text(
            '${reciter['style']} • ${reciter['riwaya']} • ${l.reciterVerseSync}',
            style: FadlFonts.ui(size: 12, color: FadlColors.sage),
          ),
          trailing: IconButton(
            tooltip: favorite ? l.reciterUnfavorite : l.reciterFavorite,
            onPressed: () => catalog.toggleFavorite(id),
            icon: Icon(
              favorite ? Icons.star_rounded : Icons.star_border_rounded,
              color: favorite ? FadlColors.gold : null,
            ),
          ),
          onTap: () => Navigator.pop(context, id),
        ),
      ),
    );
  }
}

/// "Download recitations" / "Downloaded recitations" tabs.
Future<void> showRecitationDownloads(
  BuildContext context, {
  required String reciterId,
  required int surah,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (sheet) => _RecitationDownloads(reciterId: reciterId, surah: surah),
);

class _RecitationDownloads extends StatefulWidget {
  const _RecitationDownloads({required this.reciterId, required this.surah});
  final String reciterId;
  final int surah;

  @override
  State<_RecitationDownloads> createState() => _RecitationDownloadsState();
}

class _RecitationDownloadsState extends State<_RecitationDownloads> {
  final store = AudioStore.instance;
  late String reciterId = widget.reciterId;
  late int from = widget.surah;
  late int to = widget.surah;
  bool autoDownload = false;
  bool cancelled = false;
  (int, int)? running;
  List<Map<String, dynamic>> surahs = const [];

  @override
  void initState() {
    super.initState();
    store.ready().catchError((_) {});
    QuranIndex.surahs().then((list) {
      if (mounted) setState(() => surahs = list);
    });
    AutoDownload.enabled().then((on) {
      if (mounted) setState(() => autoDownload = on);
    });
  }

  String _surahName(int id) {
    final match = surahs.where((s) => s['id'] == id);
    final name = match.isEmpty ? '' : match.first['nameAr'] as String;
    return '${prayerNumber(context, id)}. $name';
  }

  Future<void> _download() async {
    final l = prayerL(context);
    final first = from <= to ? from : to;
    final last = from <= to ? to : from;
    cancelled = false;
    try {
      for (var surah = first; surah <= last && !cancelled; surah++) {
        setState(() => running = (surah - first + 1, last - first + 1));
        await store.downloadSurah(reciterId, surah);
      }
      if (mounted && !cancelled) showToast(context, l.recitationRangeDone);
    } on AudioDownloadException catch (error) {
      if (mounted) showToast(context, error.message);
    } finally {
      if (mounted) setState(() => running = null);
    }
  }

  Future<void> _cancel() async {
    cancelled = true;
    final first = from <= to ? from : to;
    final current = running;
    if (current != null) {
      await store.cancel(reciterId, first + current.$1 - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = prayerL(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              TabBar(
                tabs: [
                  Tab(text: l.recitationDownloadTab),
                  Tab(text: l.recitationDownloadedTab),
                ],
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: store,
                  builder: (context, _) =>
                      TabBarView(children: [_downloadTab(), _downloadedTab()]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _downloadTab() {
    final l = prayerL(context);
    final reciter = reciterById(reciterId);
    final current = running;
    final first = from <= to ? from : to;
    final task = current == null
        ? null
        : store.progress(reciterId, first + current.$1 - 1);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.recitationDownloadIntro, style: FadlFonts.ui(size: 14)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _surahField(l.recitationFrom, from, (v) => from = v),
            ),
            const SizedBox(width: 12),
            Expanded(child: _surahField(l.recitationTo, to, (v) => to = v)),
          ],
        ),
        const SizedBox(height: 16),
        _label(l.recitationReciter),
        OutlinedButton(
          onPressed: current != null
              ? null
              : () async {
                  final picked = await showReciterPicker(context, reciterId);
                  if (picked != null) setState(() => reciterId = picked);
                },
          child: Text(
            reciter?['nameAr'] as String? ?? reciterId,
            style: FadlFonts.ui(size: 15),
          ),
        ),
        const SizedBox(height: 20),
        if (current != null) ...[
          Text(
            l.recitationDownloadingRange(
              prayerNumber(context, current.$1),
              prayerNumber(context, current.$2),
            ),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: task?.fraction),
          TextButton(onPressed: _cancel, child: Text(l.cancelDownload)),
        ] else
          FilledButton.icon(
            onPressed: surahs.isEmpty ? null : _download,
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text(l.recitationDownload),
          ),
        const Divider(height: 32),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: autoDownload,
          title: Text(l.recitationAutoDownload),
          subtitle: Text(l.recitationAutoDownloadHint),
          onChanged: (value) async {
            setState(() => autoDownload = value);
            await AutoDownload.setEnabled(value);
          },
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: FadlFonts.ui(size: 14, weight: FontWeight.w700),
    ),
  );

  Widget _surahField(String label, int value, ValueChanged<int> onChanged) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(label),
          DropdownButtonFormField<int>(
            initialValue: value,
            isExpanded: true,
            items: [
              for (final surah in surahs)
                DropdownMenuItem(
                  value: surah['id'] as int,
                  child: Text(
                    _surahName(surah['id'] as int),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: running != null
                ? null
                : (picked) {
                    if (picked != null) setState(() => onChanged(picked));
                  },
          ),
        ],
      );

  Widget _downloadedTab() {
    final l = prayerL(context);
    final saved = [
      for (final reciter in allReciters)
        if (store.downloadedReciters.contains(reciter['id'])) reciter,
    ];
    if (saved.isEmpty) {
      return Center(child: Text(l.recitationNoneDownloaded));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final reciter in saved)
          Card(
            child: ExpansionTile(
              title: Text(reciter['nameAr'] as String),
              subtitle: Text(
                l.recitationCompleteSurahs(
                  prayerNumber(
                    context,
                    store.completeSurahCount(reciter['id'] as String),
                  ),
                ),
              ),
              children: [
                for (var surah = 1; surah <= 114; surah++)
                  if (store.status(reciter['id'] as String, surah) !=
                      DownloadStatus.none)
                    ListTile(
                      title: Text(_surahName(surah)),
                      trailing: IconButton(
                        tooltip: l.delete,
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () =>
                            store.deleteSurah(reciter['id'] as String, surah),
                      ),
                    ),
              ],
            ),
          ),
      ],
    );
  }
}
