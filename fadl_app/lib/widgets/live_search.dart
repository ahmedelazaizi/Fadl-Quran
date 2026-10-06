import 'dart:async';

import 'package:flutter/material.dart';

import '../core/offline_athkar.dart' show normalizeArabic;
import '../l10n/prayer_labels.dart';

/// Matches Arabic names without tashkeel or spelling variants, and numbers.
bool matchesLiveSearch(String text, String query) {
  // Quranic «صلوة» and common «صلاة» use different medial letters.
  String searchable(String source) =>
      normalizeArabic(source).replaceAll('صلوه', 'صلاه');
  final needle = searchable(query.replaceFirst(RegExp(r'^سور[ةه]\s*'), ''));
  return needle.isNotEmpty && searchable(text).contains(needle);
}

bool matchesSurahSearch(Map<String, dynamic> surah, String query) {
  final raw = query.trim();
  if (raw.isEmpty) return true;
  final western = raw.replaceAllMapped(
    RegExp('[٠-٩]'),
    (m) => '${m.group(0)!.codeUnitAt(0) - 0x0660}',
  );
  return matchesLiveSearch(surah['nameAr'] as String, raw) ||
      '${surah['id']}' == western ||
      '${surah['startPage']}' == western ||
      (surah['nameTranslit'] as String? ?? '').toLowerCase().contains(
        raw.toLowerCase(),
      );
}

class LiveSearchSuggestion<T> {
  const LiveSearchSuggestion(this.value, this.title, {this.subtitle});
  final T value;
  final String title;
  final String? subtitle;
}

/// A debounced, inline search field. Older asynchronous responses are discarded.
class LiveSearch<T> extends StatefulWidget {
  const LiveSearch({
    super.key,
    required this.hintText,
    required this.search,
    required this.onSelected,
    this.controller,
    this.onChanged,
    this.onResults,
    this.onSubmitted,
    this.prefixIcon = Icons.search_rounded,
    this.minLength = 1,
    this.debounce = const Duration(milliseconds: 300),
    this.maxSuggestions = 5,
  });

  final String hintText;
  final Future<List<LiveSearchSuggestion<T>>> Function(String query) search;
  final ValueChanged<T> onSelected;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<List<LiveSearchSuggestion<T>>>? onResults;
  final ValueChanged<String>? onSubmitted;
  final IconData prefixIcon;
  final int minLength;
  final Duration debounce;
  final int maxSuggestions;

  @override
  State<LiveSearch<T>> createState() => _LiveSearchState<T>();
}

class _LiveSearchState<T> extends State<LiveSearch<T>> {
  TextEditingController? _owned;
  TextEditingController get _controller =>
      widget.controller ?? (_owned ??= TextEditingController());
  Timer? _timer;
  int _generation = 0;
  bool _loading = false;
  bool _searched = false;
  Object? _error;
  bool _showSuggestions = true;
  List<LiveSearchSuggestion<T>> _suggestions = [];

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    _owned?.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _timer?.cancel();
    ++_generation;
    final query = value.trim();
    widget.onChanged?.call(query);
    setState(() {
      _suggestions = [];
      _loading = false;
      _searched = false;
      _error = null;
      _showSuggestions = true;
    });
    if (query.length < widget.minLength) {
      widget.onResults?.call([]);
      return;
    }
    final token = _generation;
    _timer = Timer(widget.debounce, () => _lookup(query, token));
  }

  Future<void> _lookup(String query, int token) async {
    if (!mounted || token != _generation) return;
    setState(() => _loading = true);
    try {
      final found = await widget.search(query);
      if (!mounted || token != _generation) return;
      setState(() {
        _suggestions = found.take(widget.maxSuggestions).toList();
        _loading = false;
        _searched = true;
        _error = null;
      });
      widget.onResults?.call(found);
    } catch (error) {
      if (!mounted || token != _generation) return;
      setState(() {
        _loading = false;
        _searched = true;
        _error = error;
        _suggestions = [];
      });
    }
  }

  void _submit(String value) {
    _timer?.cancel();
    final query = value.trim();
    if (query.length >= widget.minLength) {
      _lookup(query, ++_generation);
      widget.onSubmitted?.call(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _controller.text;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            onChanged: _changed,
            onSubmitted: _submit,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: widget.hintText,
              prefixIcon: Icon(widget.prefixIcon),
              suffixIcon: _loading
                  ? const SizedBox(
                      width: 48,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: prayerL(context).a11yClear,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _controller.clear();
                        _changed('');
                      },
                    ),
            ),
          ),
          if (_showSuggestions &&
              text.trim().length >= widget.minLength &&
              _searched)
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: _suggestions.isEmpty
                  ? ListTile(
                      title: Text(
                        _error == null
                            ? prayerL(context).searchNoResults
                            : prayerL(context).searchFailed('$_error'),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final item in _suggestions)
                          ListTile(
                            dense: true,
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: item.subtitle == null
                                ? null
                                : Text(
                                    item.subtitle!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            onTap: () {
                              setState(() => _showSuggestions = false);
                              widget.onSelected(item.value);
                            },
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}
