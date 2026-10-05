import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/offline_hadith.dart';
import '../../core/theme.dart';
import '../../l10n/prayer_labels.dart';
import '../../widgets/common.dart';
import 'hadith_card.dart';

/// Hadiths of a book (optionally one chapter), loaded 20 at a time on scroll.
class HadithListScreen extends StatefulWidget {
  const HadithListScreen({
    super.key,
    required this.slug,
    required this.title,
    this.chapterId,
  });
  final String slug;
  final String title;
  final int? chapterId;

  @override
  State<HadithListScreen> createState() => _HadithListScreenState();
}

class _HadithListScreenState extends State<HadithListScreen> {
  static const _pageSize = 20;
  final _items = <Map<String, dynamic>>[];
  final _scroll = ScrollController();
  int? _total;
  bool _loading = false;
  String? _error;

  bool get _hasMore => _total == null || _items.length < _total!;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _loadMore();
    });
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = Api.hasBackend
          ? await Api.instance.get('/hadith/books/${widget.slug}/hadiths', {
                  'chapterId': widget.chapterId,
                  'limit': _pageSize,
                  'offset': _items.length,
                })
                as Map<String, dynamic>
          : await OfflineHadith.instance.hadiths(
              widget.slug,
              chapterId: widget.chapterId,
              limit: _pageSize,
              offset: _items.length,
            );
      final page = (res['hadiths'] as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        _total = page.isEmpty
            ? _items.length
            : (res['total'] as num?)?.toInt() ?? _items.length;
      });
    } on Exception catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _items.isEmpty && _error != null
          ? ErrorCard(message: _error!, onRetry: _loadMore)
          : _items.isEmpty && !_hasMore
          ? Center(
              child: Text(
                prayerL(context).hadithNoItems,
                style: FadlFonts.ui(size: 15, color: scheme.onSurfaceVariant),
              ),
            )
          : ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: _items.length + 2,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return Text(
                    _total == null
                        ? ''
                        : prayerL(
                            context,
                          ).hadithCount(prayerNumber(context, _total!)),
                    style: FadlFonts.ui(
                      size: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  );
                }
                if (i <= _items.length) {
                  return HadithCard(hadith: _items[i - 1], showBook: false);
                }
                if (_error != null) {
                  return Center(
                    child: TextButton.icon(
                      onPressed: _loadMore,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(_error!),
                    ),
                  );
                }
                return _hasMore
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : const SizedBox(height: 8);
              },
            ),
    );
  }
}
