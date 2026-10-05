import 'package:flutter/material.dart';

import '../core/audio_store.dart';
import '../core/format.dart';
import '../core/reciters.dart';
import '../core/theme.dart';
import '../l10n/prayer_labels.dart';
import '../widgets/common.dart';

/// Recitations saved on the device for listening without internet.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final store = AudioStore.instance;
  late Future<_Summary> summary = _summarize();

  @override
  void initState() {
    super.initState();
    store.addListener(_changed);
  }

  @override
  void dispose() {
    store.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() => summary = _summarize());
  }

  Future<_Summary> _summarize() async {
    await store.ready();
    final rows = <_ReciterRow>[];
    for (final reciter in reciters) {
      final id = reciter['id'] as String;
      if (!store.downloadedReciters.contains(id)) continue;
      rows.add(
        _ReciterRow(
          reciter,
          store.completeSurahCount(id),
          await store.reciterSize(id),
        ),
      );
    }
    return _Summary(await store.totalSize(), rows);
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(prayerL(dialog).libraryCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              style: TextButton.styleFrom(foregroundColor: FadlColors.error),
              child: Text(prayerL(dialog).libraryDelete),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _deleteReciter(_ReciterRow row) async {
    final name = row.reciter['nameAr'] as String;
    if (!await _confirm(prayerL(context).downloadsDeleteTitle, prayerL(context).downloadsDeleteReciterConfirm(name))) {
      return;
    }
    await store.deleteReciter(row.reciter['id'] as String);
    if (mounted) showToast(context, prayerL(context).downloadsDeletedReciter(name));
  }

  Future<void> _deleteAll() async {
    if (!await _confirm(
      prayerL(context).downloadsDeleteAllTitle,
      prayerL(context).downloadsDeleteAllConfirm,
    )) {
      return;
    }
    await store.deleteAll();
    if (mounted) showToast(context, prayerL(context).downloadsDeletedAll);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(prayerL(context).downloads)),
    body: FutureBuilder<_Summary>(
      future: summary,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorCard(
            message: prayerL(context).downloadsReadError,
            onRetry: () => setState(() => summary = _summarize()),
          );
        }
        final data = snapshot.data;
        if (data == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final scheme = Theme.of(context).colorScheme;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FadlCard(
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: FadlColors.mintSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.download_for_offline_outlined,
                      color: FadlColors.sage,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prayerL(context).downloadsUsedSpace,
                          style: FadlFonts.ui(size: 13),
                        ),
                        Text(
                          formatBytes(data.totalBytes),
                          style: FadlFonts.ui(
                            size: 18,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (data.rows.isNotEmpty)
                    TextButton.icon(
                      onPressed: _deleteAll,
                      style: TextButton.styleFrom(
                        foregroundColor: FadlColors.error,
                      ),
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: Text(prayerL(context).downloadsDeleteAll),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SectionTitle(prayerL(context).reciters),
            if (data.rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  prayerL(context).downloadsEmpty,
                  textAlign: TextAlign.center,
                  style: FadlFonts.ui(size: 14, color: scheme.onSurfaceVariant),
                ),
              ),
            for (final row in data.rows) ...[
              FadlCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.headphones_outlined),
                  ),
                  title: Text(
                    '${row.reciter['nameAr']} (${row.reciter['style']})',
                    style: FadlFonts.ui(size: 15, weight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${prayerL(context).downloadsCompleteSurahs(prayerNumber(context, row.completeSurahs))} • ${formatBytes(row.bytes)}',
                  ),
                  trailing: IconButton(
                    tooltip: prayerL(context).downloadsDeleteReciterTooltip,
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => _deleteReciter(row),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    ),
  );
}

class _ReciterRow {
  const _ReciterRow(this.reciter, this.completeSurahs, this.bytes);
  final Map<String, dynamic> reciter;
  final int completeSurahs;
  final int bytes;
}

class _Summary {
  const _Summary(this.totalBytes, this.rows);
  final int totalBytes;
  final List<_ReciterRow> rows;
}
