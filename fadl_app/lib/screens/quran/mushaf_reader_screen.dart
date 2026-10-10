import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/api.dart';
import '../../core/app_state.dart';
import '../../core/auto_download.dart';
import '../../core/format.dart';
import '../../core/local_user_data.dart';
import '../../core/mushaf_layout.dart';
import '../../core/offline_tafsir.dart';
import '../../core/offline_tajweed.dart';
import '../../core/tajweed_schemes.dart';
import '../assistant_screen.dart';
import 'mushaf_index_screen.dart';
import '../settings_screen.dart';
import '../../core/quran_data.dart';
import '../../core/quran_storage.dart';
import '../../core/quran_audio.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_labels.dart';
import '../../widgets/common.dart';
import '../../widgets/live_search.dart';
import '../../widgets/measure_size.dart';
import 'audio_player_screen.dart';
import 'memorization_sheet.dart';
import 'quran_widgets.dart';
import 'recitation_sheets.dart';
import 'reader_audio_focus.dart';

const _totalPages = 604;
String _number(BuildContext context, Object? number) =>
    Localizations.localeOf(context).languageCode == 'ar'
    ? arNum(number ?? 0)
    : '$number';
const _basmala = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

/// Reader-local display modes (do not change the global app theme).
enum ReaderMode { day, night, black }

class _Palette {
  const _Palette({
    required this.canvas,
    required this.page,
    required this.text,
    required this.muted,
    required this.accent,
    required this.highlight,
    required this.frame,
  });
  final Color canvas;
  final Color page;
  final Color text;
  final Color muted;
  final Color accent;
  final Color highlight;
  final Color frame;

  static _Palette of(ReaderMode mode) => switch (mode) {
    ReaderMode.day => const _Palette(
      canvas: FadlColors.parchment,
      page: Color(0xFFFCFAF3),
      text: FadlColors.text,
      muted: FadlColors.textMuted,
      accent: FadlColors.primary,
      highlight: FadlColors.goldSoft,
      frame: FadlColors.surfaceContainer,
    ),
    ReaderMode.night => const _Palette(
      canvas: FadlColors.darkCanvas,
      page: FadlColors.darkSurface,
      text: Color(0xFFEDE6D3),
      muted: Color(0xFFB7C4BE),
      accent: FadlColors.goldLight,
      highlight: Color(0x33C7A75C),
      frame: FadlColors.darkSurfaceHigh,
    ),
    ReaderMode.black => const _Palette(
      canvas: Colors.black,
      page: Colors.black,
      text: Color(0xFFE8E2D0),
      muted: Color(0xFF9AA39F),
      accent: FadlColors.goldLight,
      highlight: Color(0x33C7A75C),
      frame: Color(0xFF111111),
    ),
  };
}

/// Page-by-page Madani mushaf (604 pages), right-to-left like a printed mushaf.
class MushafReaderScreen extends StatefulWidget {
  const MushafReaderScreen({
    super.key,
    this.initialPage = 1,
    this.highlightAyahKey,
  });
  final int initialPage;
  final String? highlightAyahKey;

  @override
  State<MushafReaderScreen> createState() => _MushafReaderScreenState();
}

class _MushafReaderScreenState extends State<MushafReaderScreen>
    with WidgetsBindingObserver {
  late final PageController _controller;
  late int _page = widget.initialPage.clamp(1, _totalPages);
  late final ValueNotifier<int> _visiblePage = ValueNotifier(_page);
  late String? _selectedKey = widget.highlightAyahKey;
  ReaderMode _mode = ReaderMode.day;
  Timer? _lastReadTimer;
  String? _lastSavedKey;
  final _audio = QuranAudio.instance;
  final _audioFocus = ReaderAudioFocus();
  bool _tajweedEnabled = false;
  TajweedScheme _tajweedScheme = TajweedScheme.simple;
  int? _sliderPage;
  bool _chromeVisible = true;

  /// Heights of the floating top and bottom panels (safe area included), so
  /// the page shrinks to show every line between them instead of under them.
  double _topChrome = 0;
  double _bottomChrome = 0;

  void _setTopChrome(double height) {
    if (mounted && height != _topChrome) setState(() => _topChrome = height);
  }

  void _setBottomChrome(double height) {
    if (mounted && height != _bottomChrome) {
      setState(() => _bottomChrome = height);
    }
  }

  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        _chromeVisible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
      ),
    );
  }

  final _tajweed = OfflineTajweed.instance;

  Future<void> _loadTajweed() async {
    await _tajweed.ready();
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _tajweedEnabled = prefs.getBool(tajweedPreferenceKey) ?? false;
        _tajweedScheme = TajweedScheme.values.firstWhere(
          (scheme) =>
              scheme.name == prefs.getString(tajweedSchemePreferenceKey),
          orElse: () => TajweedScheme.simple,
        );
      });
    }
  }

  Future<void> _toggleTajweed() async {
    if (!_tajweed.isDownloaded) return;
    final enabled = !_tajweedEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(tajweedPreferenceKey, enabled);
    if (mounted) setState(() => _tajweedEnabled = enabled);
  }

  void _onTajweedChanged() {
    if (mounted) {
      setState(() {
        if (!_tajweed.isDownloaded) _tajweedEnabled = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setScreenAwake(true);
    _controller = PageController(initialPage: _page - 1);
    _audio.addListener(_onAudioChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onAudioChanged());
    _tajweed.addListener(_onTajweedChanged);
    unawaited(_loadTajweed());
    unawaited(_audio.loadSettings());
    final dark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    if (dark) _mode = ReaderMode.night;
    _scheduleLastRead(_page);
    for (var offset = -2; offset <= 2; offset++) {
      if (offset != 0) QuranPages.prefetch(_page + offset);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _setScreenAwake(state == AppLifecycleState.resumed);
  }

  Future<void> _setScreenAwake(bool awake) async {
    try {
      await WakelockPlus.toggle(enable: awake);
    } catch (_) {
      // Screen-on is best effort if the platform plugin is unavailable.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setScreenAwake(false);
    if (!_chromeVisible) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    }
    _lastReadTimer?.cancel();
    _audio.removeListener(_onAudioChanged);
    _tajweed.removeListener(_onTajweedChanged);
    _visiblePage.dispose();
    _controller.dispose();
    super.dispose();
  }

  static Future<Map<String, dynamic>> loadPage(int page) =>
      QuranPages.load(page);

  bool _lastPlaying = false;
  int _lastCountdown = 0;
  int _lastAudioSurah = 0;

  void _onAudioChanged() {
    if (!mounted) return;
    final focusChanged = _audioFocus.update(
      ayahKey: _audio.ayahKey,
      sourceActive:
          _audio.playlist != null &&
          _audio.player.processingState != ProcessingState.idle,
    );
    if (focusChanged && _audioFocus.ayahKey != null) {
      unawaited(_followAyah(_audioFocus.ayahKey!, _audioFocus.revision));
    }
    final changed =
        focusChanged ||
        _lastPlaying != _audio.playing ||
        _lastCountdown != _audio.countdown;
    _lastPlaying = _audio.playing;
    _lastCountdown = _audio.countdown;
    // A new surah started playing: optionally keep it for offline use.
    if (_audio.surahId > 0 && _audio.surahId != _lastAudioSurah) {
      _lastAudioSurah = _audio.surahId;
      unawaited(
        AutoDownload.instance.consider(_audio.reciterId, _audio.surahId),
      );
    }
    if (changed) setState(() {});
  }

  Future<void> _followAyah(String key, int revision) async {
    final ayah = (await QuranData.load()).ayah(key);
    if (!mounted || !_audioFocus.isCurrent(revision) || ayah == null) return;
    final page = ayah['page'] as int;
    if (_page != page) _goTo(page);
  }

  Future<void> _playAyah(int surahId, int number) async {
    final state = context.read<AppState>();
    try {
      if (_audio.surahId == surahId &&
          _audio.reciterId == state.reciterId &&
          _audio.ayahs.isNotEmpty) {
        await _audio.seekAyah(number);
      } else {
        await _audio.start(
          surahId,
          number,
          state.reciterId,
          continuousPlay: (state.settings['continuousPlay'] as bool?) ?? true,
        );
      }
    } catch (_) {
      if (mounted) {
        showToast(
          context,
          _audio.error ?? AppLocalizations.of(context)!.recitationError,
        );
      }
    }
  }

  Future<void> _bookmarkCurrentPage() async {
    try {
      final contents = await loadPage(_page);
      final ayahs = (contents['ayahs'] as List).cast<Map<String, dynamic>>();
      final chosen = ayahs.where((ayah) => ayah['key'] == _selectedKey);
      final key =
          (chosen.isEmpty ? ayahs.first : chosen.first)['key'] as String;
      if (Api.hasBackend) {
        await Api.instance.post('/me/bookmarks', {'ayahKey': key});
      } else {
        await LocalUserData.instance.addBookmark(key);
      }
      if (mounted) {
        showToast(context, AppLocalizations.of(context)!.bookmarkSaved);
      }
    } on ApiException catch (error) {
      if (mounted) showToast(context, error.message);
    } on LocalDataException catch (error) {
      if (mounted) showToast(context, error.message);
    } on Exception {
      if (mounted) {
        showToast(context, AppLocalizations.of(context)!.pageLoadError);
      }
    }
  }

  Future<void> _playCurrentPage() async {
    try {
      final contents = await loadPage(_page);
      final ayahs = (contents['ayahs'] as List).cast<Map<String, dynamic>>();
      final selected = ayahs.where((ayah) => ayah['key'] == _selectedKey);
      final ayah = selected.isEmpty ? ayahs.first : selected.first;
      await _playAyah(ayah['surahId'] as int, ayah['number'] as int);
    } catch (_) {
      if (mounted) {
        showToast(context, AppLocalizations.of(context)!.pageLoadError);
      }
    }
  }

  void _onPageChanged(int index) {
    _page = index + 1;
    _visiblePage.value = _page;
    _scheduleLastRead(_page);
    // Warm the neighbours for smooth swiping.
    for (var offset = -2; offset <= 2; offset++) {
      if (offset != 0) QuranPages.prefetch(_page + offset);
    }
  }

  /// Saves the reading position after the page has been visible for a moment.
  void _scheduleLastRead(int page) {
    _lastReadTimer?.cancel();
    _lastReadTimer = Timer(const Duration(seconds: 3), () async {
      try {
        final data = await loadPage(page);
        final ayahs = (data['ayahs'] as List).cast<Map<String, dynamic>>();
        final highlighted = ayahs.any((a) => a['key'] == _selectedKey)
            ? _selectedKey
            : null;
        final key = highlighted ?? ayahs.first['key'] as String;
        if (!mounted || page != _page) return;
        // The page stayed open: optionally keep its surah for offline use.
        final surahId = ayahs.firstWhere((a) => a['key'] == key)['surahId'];
        unawaited(
          AutoDownload.instance.consider(
            context.read<AppState>().reciterId,
            surahId as int,
          ),
        );
        if (key == _lastSavedKey) return;
        await _saveLastRead(key, data: data);
      } catch (_) {
        // Best effort; ignore offline failures.
      }
    });
  }

  Future<void> _saveLastRead(String key, {Map<String, dynamic>? data}) async {
    data ??= await loadPage(_page);
    final ayah = (data['ayahs'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((a) => a['key'] == key);
    final surah = (data['surahs'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((s) => s['id'] == ayah['surahId']);
    await LastReadStore.instance.save(
      ReadingPosition(
        key: key,
        page: data['page'] as int,
        number: ayah['number'] as int,
        juz: ayah['juz'] as int? ?? data['juz'] as int,
        surahName: surah['nameAr'] as String,
      ),
    );
    _lastSavedKey = key;
    if (Api.hasBackend) {
      try {
        await Api.instance.put('/me/last-read', {'ayahKey': key});
      } on ApiException {
        // The local reading position is still available offline.
      }
    }
  }

  void _goTo(int page) {
    final p = page.clamp(1, _totalPages);
    _controller.jumpToPage(p - 1);
  }

  Future<void> _changeFont(int delta) async {
    final state = context.read<AppState>();
    final next = (state.quranFontSize.round() + delta).clamp(18, 32);
    if (next == state.quranFontSize.round()) return;
    try {
      await state.updateSettings({'fontSize': next});
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  void _openBookmarks() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LocalBookmarksSheet(
        onOpen: (page, key) {
          Navigator.pop(context);
          _goTo(page);
          setState(() => _selectedKey = key);
        },
      ),
    );
  }

  void _openJumpSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _JumpSheet(page: _page, onJump: _goTo),
    );
  }

  Future<void> _onAyahTap(Map<String, dynamic> ayah, String surahName) async {
    setState(() => _selectedKey = ayah['key'] as String);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AyahSheet(
        ayah: ayah,
        surahName: surahName,
        onMarkRead: () => _saveLastRead(ayah['key'] as String),
        onListen: () =>
            _playAyah(ayah['surahId'] as int, ayah['number'] as int),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = _Palette.of(_mode);
    final fontSize = context.watch<AppState>().quranFontSize;
    // Notch and system bars; viewPadding keeps the cutout in immersive mode.
    final safe = MediaQuery.viewPaddingOf(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      body: Stack(
        children: [
          Positioned.fill(
            // Page 1 sits on the right; keep swipe direction independent of chrome.
            // The page stays clear of the notch and system bars, and of the
            // floating panels while they show.
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                top: _chromeVisible ? _topChrome : safe.top,
                bottom: _chromeVisible ? _bottomChrome : safe.bottom,
                left: safe.left,
                right: safe.right,
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _totalPages,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) => RepaintBoundary(
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: loadPage(index + 1),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return ErrorCard(
                            message: '${snap.error}',
                            onRetry: () => setState(() {}),
                          );
                        }
                        if (!snap.hasData) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: palette.accent,
                            ),
                          );
                        }
                        return Directionality(
                          textDirection: TextDirection.rtl,
                          child: _MushafPage(
                            data: snap.data!,
                            palette: palette,
                            fontSize: fontSize,
                            colored: _tajweedEnabled && _tajweed.isDownloaded,
                            tajweed: _tajweed,
                            scheme: _tajweedScheme,
                            dark: _mode != ReaderMode.day,
                            selectedKey: _audioFocus.highlightedKey(
                              _selectedKey,
                            ),
                            onAyahTap: _onAyahTap,
                            onEmptyTap: _toggleChrome,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_chromeVisible)
            Positioned(
              top: 0,
              left: 12,
              right: 12,
              child: MeasureHeight(
                onChange: _setTopChrome,
                child: SafeArea(
                  bottom: false,
                  child: _floatingPanel(
                    palette,
                    Row(
                      children: [
                        IconButton(
                          tooltip: AppLocalizations.of(context)!.back,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        Expanded(
                          child: ValueListenableBuilder<int>(
                            valueListenable: _visiblePage,
                            builder: (_, page, _) =>
                                _HeaderTitle(page: page, palette: palette),
                          ),
                        ),
                        IconButton(
                          tooltip: _mode == ReaderMode.day
                              ? AppLocalizations.of(context)!.nightMode
                              : AppLocalizations.of(context)!.dayMode,
                          icon: Icon(
                            _mode == ReaderMode.day
                                ? Icons.dark_mode_outlined
                                : Icons.light_mode_outlined,
                          ),
                          onPressed: () => setState(
                            () => _mode = _mode == ReaderMode.day
                                ? ReaderMode.night
                                : ReaderMode.day,
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.tune_rounded),
                          onSelected: (v) {
                            switch (v) {
                              case 'day':
                                setState(() => _mode = ReaderMode.day);
                              case 'night':
                                setState(() => _mode = ReaderMode.night);
                              case 'black':
                                setState(() => _mode = ReaderMode.black);
                              case 'bigger':
                                _changeFont(2);
                              case 'smaller':
                                _changeFont(-2);
                              case 'jump':
                                _openJumpSheet();
                              case 'dedicate':
                                dedicate(
                                  context,
                                  'READING',
                                  refKey: 'page:$_page',
                                );
                              case 'bookmarks':
                                _openBookmarks();
                              case 'tajweed':
                                _toggleTajweed();
                              case 'scheme':
                                _openSchemePicker();
                            }
                          },
                          itemBuilder: (_) => [
                            _menuItem(
                              'day',
                              Icons.light_mode_outlined,
                              AppLocalizations.of(context)!.light,
                              _mode == ReaderMode.day,
                            ),
                            _menuItem(
                              'night',
                              Icons.nights_stay_outlined,
                              AppLocalizations.of(context)!.dark,
                              _mode == ReaderMode.night,
                            ),
                            _menuItem(
                              'black',
                              Icons.contrast_rounded,
                              AppLocalizations.of(context)!.blackMode,
                              _mode == ReaderMode.black,
                            ),
                            const PopupMenuDivider(),
                            _menuItem(
                              'bigger',
                              Icons.text_increase_rounded,
                              AppLocalizations.of(context)!.increaseFont(
                                _number(context, fontSize.round()),
                              ),
                              false,
                            ),
                            _menuItem(
                              'smaller',
                              Icons.text_decrease_rounded,
                              AppLocalizations.of(context)!.decreaseFont,
                              false,
                            ),
                            const PopupMenuDivider(),
                            if (_tajweed.isDownloaded)
                              _menuItem(
                                'tajweed',
                                Icons.color_lens_outlined,
                                AppLocalizations.of(context)!.coloredTajweed,
                                _tajweedEnabled,
                              ),
                            _menuItem(
                              'scheme',
                              Icons.palette_outlined,
                              AppLocalizations.of(
                                context,
                              )!.tajweedScheme(_schemeName(_tajweedScheme)),
                              false,
                            ),
                            _menuItem(
                              'jump',
                              Icons.menu_book_outlined,
                              AppLocalizations.of(context)!.goToPage,
                              false,
                            ),
                            if (!Api.hasBackend)
                              _menuItem(
                                'bookmarks',
                                Icons.bookmarks_outlined,
                                AppLocalizations.of(context)!.myBookmarks,
                                false,
                              ),
                            _menuItem(
                              'dedicate',
                              Icons.volunteer_activism_outlined,
                              AppLocalizations.of(context)!.dedicateReading,
                              false,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_chromeVisible)
            Positioned(
              bottom: 0,
              left: 12,
              right: 12,
              child: MeasureHeight(
                onChange: _setBottomChrome,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_tajweedEnabled && _tajweed.isDownloaded)
                        _floatingPanel(palette, _tajweedLegend(palette)),
                      if (_audio.ayahs.isNotEmpty)
                        _floatingPanel(palette, _audioStrip(palette)),
                      ValueListenableBuilder<int>(
                        valueListenable: _visiblePage,
                        builder: (_, page, _) => _pageSlider(palette, page),
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: _visiblePage,
                        builder: (_, page, _) =>
                            _floatingPanel(palette, _quickActions(page)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _schemeName(TajweedScheme scheme) {
    final l = AppLocalizations.of(context)!;
    return scheme == TajweedScheme.simple
        ? l.simpleTajweed
        : l.darAlMaarifaTajweed;
  }

  String _categoryName(TajweedCategory category) {
    final l = AppLocalizations.of(context)!;
    return switch (category.rules.first) {
      'madda_normal' =>
        category.rules.length == 1 ? l.tajweedTwoCounts : l.tajweedMadd,
      'madda_permissible' => l.tajweedOptionalCounts,
      'madda_obligatory' => l.tajweedObligatoryCounts,
      'madda_necessary' => l.tajweedNecessaryCounts,
      'ghunnah' =>
        category.rules.length == 4 ? l.tajweedGhunnah : l.tajweedNasalization,
      'idgham_wo_ghunnah' =>
        category.rules.length > 5 ? l.tajweedUnpronounced : l.tajweedIdgham,
      'qalaqah' => l.tajweedQalqalah,
      'ham_wasl' => l.tajweedWasl,
      'slnt' => l.tajweedSilent,
      _ => l.tajweedUnpronounced,
    };
  }

  Widget _floatingPanel(_Palette palette, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: palette.frame.withValues(alpha: 0.93),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.muted.withValues(alpha: 0.25)),
          ),
          child: IconTheme(
            data: IconThemeData(color: palette.accent),
            child: child,
          ),
        ),
      ),
    ),
  );

  Widget _pageSlider(_Palette palette, int page) => _floatingPanel(
    palette,
    Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_sliderPage != null)
          _HeaderTitle(page: _sliderPage!, palette: palette),
        Directionality(
          textDirection: TextDirection.rtl,
          child: Slider(
            value: (_sliderPage ?? page).toDouble(),
            min: 1,
            max: _totalPages.toDouble(),
            divisions: _totalPages - 1,
            label: _number(context, _sliderPage ?? page),
            onChanged: (value) => setState(() => _sliderPage = value.round()),
            onChangeEnd: (value) {
              setState(() => _sliderPage = null);
              _goTo(value.round());
            },
          ),
        ),
      ],
    ),
  );

  // Follows the always-RTL page flow so "previous" sits on the side earlier
  // pages come from, in every UI language.
  Widget _quickActions(int page) => Directionality(
    textDirection: TextDirection.rtl,
    child: _quickActionsRow(page),
  );

  // Each button takes an equal share, so the 48 px tap targets never overflow
  // a 360 px-wide phone.
  Widget _quickActionsRow(int page) => Row(
    children: [
      for (final button in _quickActionButtons(page)) Expanded(child: button),
    ],
  );

  List<Widget> _quickActionButtons(int page) => [
    IconButton(
      constraints: const BoxConstraints(minWidth: 38, minHeight: 48),
      padding: EdgeInsets.zero,
      tooltip: AppLocalizations.of(context)!.previous,
      onPressed: page > 1
          ? () =>
                _controller.previousPage(duration: _turn, curve: Curves.easeOut)
          : null,
      icon: const Icon(Icons.chevron_left_rounded),
    ),
    _quickButton(
      _audio.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
      AppLocalizations.of(context)!.togglePlayback,
      _audio.playing ? _audio.pause : _playCurrentPage,
    ),
    _quickButton(
      Icons.bookmark_add_outlined,
      AppLocalizations.of(context)!.bookmarkPage,
      _bookmarkCurrentPage,
    ),
    _quickButton(
      Icons.menu_book_outlined,
      AppLocalizations.of(context)!.mushafIndex,
      () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const MushafIndexScreen()),
      ),
    ),
    _quickButton(
      Icons.swap_horiz_rounded,
      AppLocalizations.of(context)!.goTo,
      _openJumpSheet,
    ),
    _quickButton(
      Icons.search_rounded,
      AppLocalizations.of(context)!.quickSearch,
      () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const AssistantScreen(openSearch: true),
        ),
      ),
    ),
    IconButton(
      constraints: const BoxConstraints(minWidth: 38, minHeight: 48),
      padding: EdgeInsets.zero,
      tooltip: AppLocalizations.of(context)!.next,
      onPressed: page < _totalPages
          ? () => _controller.nextPage(duration: _turn, curve: Curves.easeOut)
          : null,
      icon: const Icon(Icons.chevron_right_rounded),
    ),
  ];

  Widget _quickButton(IconData icon, String tooltip, VoidCallback action) =>
      IconButton(
        constraints: const BoxConstraints(minWidth: 38, minHeight: 48),
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        onPressed: action,
        icon: Icon(icon),
      );

  Future<void> _openSchemePicker() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.tajweedColors,
                style: FadlFonts.heading(size: 20),
              ),
              for (final scheme in TajweedScheme.values)
                ListTile(
                  title: Text(_schemeName(scheme)),
                  trailing: scheme == _tajweedScheme
                      ? const Icon(Icons.check)
                      : null,
                  subtitle: Wrap(
                    spacing: 10,
                    children: [
                      for (final category in scheme.categories)
                        Text(
                          _categoryName(category),
                          style: FadlFonts.ui(
                            size: 12,
                            color: scheme.colorFor(
                              category.rules.first,
                              dark: _mode != ReaderMode.day,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(
                      tajweedSchemePreferenceKey,
                      scheme.name,
                    );
                    if (!mounted) return;
                    setState(() => _tajweedScheme = scheme);
                    if (sheet.mounted) Navigator.pop(sheet);
                  },
                ),
              Text(AppLocalizations.of(context)!.emphasisNotMarked),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tajweedLegend(_Palette palette) => Container(
    color: Colors.transparent,
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      children: [
        for (final category in _tajweedScheme.categories)
          Text(
            _categoryName(category),
            style: FadlFonts.ui(
              size: 11,
              color: _tajweedScheme.colorFor(
                category.rules.first,
                dark: _mode != ReaderMode.day,
              ),
            ),
          ),
        Text(
          AppLocalizations.of(context)!.colorsIllustrative,
          style: FadlFonts.ui(size: 11, color: palette.muted),
        ),
      ],
    ),
  );

  Widget _audioStrip(_Palette palette) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 390;
      return Container(
        color: palette.frame,
        child: Row(
          children: [
            IconButton(
              tooltip: _audio.playing
                  ? AppLocalizations.of(context)!.pause
                  : AppLocalizations.of(context)!.playFromPage,
              onPressed: () => _audio.playing
                  ? _audio.pause()
                  : _audio.ayahs.isEmpty
                  ? _playCurrentPage()
                  : _audio.resume(),
              icon: Icon(
                _audio.playing ? Icons.pause_circle : Icons.play_circle,
                size: 34,
                color: palette.accent,
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const AudioPlayerScreen(useCurrent: true),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _audio.reciter?['nameAr'] as String? ??
                          AppLocalizations.of(context)!.listenWhileReading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FadlFonts.ui(size: 13, color: palette.text),
                    ),
                    if (!compact)
                      Text(
                        _audio.countdown > 0
                            ? AppLocalizations.of(
                                context,
                              )!.repeatNow(_number(context, _audio.countdown))
                            : _audio.ayahNumber == 0
                            ? AppLocalizations.of(context)!.startSelectedVerse
                            : AppLocalizations.of(context)!.surahAndVerse(
                                _number(context, _audio.surahId),
                                _number(context, _audio.ayahNumber),
                              ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FadlFonts.ui(size: 12, color: palette.muted),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context)!.previousVerse,
              onPressed: _audio.ayahNumber > 1
                  ? () => _audio.seekAyah(_audio.ayahNumber - 1)
                  : null,
              icon: Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.skip_next_rounded
                    : Icons.skip_previous_rounded,
              ),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context)!.nextVerse,
              onPressed: _audio.ayahNumber < _audio.ayahs.length
                  ? () => _audio.seekAyah(_audio.ayahNumber + 1)
                  : null,
              icon: Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.skip_previous_rounded
                    : Icons.skip_next_rounded,
              ),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context)!.memorizationSettings,
              onPressed: () => openMemorizationSheet(context),
              icon: const Icon(Icons.repeat_rounded),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context)!.chooseReciter,
              onPressed: _pickReciter,
              icon: const Icon(Icons.record_voice_over_outlined),
            ),
            IconButton(
              tooltip: prayerL(context).recitationsButton,
              onPressed: _openRecitationDownloads,
              icon: const Icon(Icons.cloud_download_outlined),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _pickReciter() async {
    final state = context.read<AppState>();
    final picked = await showReciterPicker(context, state.reciterId);
    if (picked == null || picked == state.reciterId) return;
    try {
      await state.updateSettings({'reciterId': picked});
      if (mounted && _audio.ayahNumber > 0) {
        await _playAyah(_audio.surahId, _audio.ayahNumber);
      }
    } on ApiException catch (failure) {
      if (mounted) showToast(context, failure.message);
    }
  }

  Future<void> _openRecitationDownloads() async {
    final surah = _audio.surahId > 0
        ? _audio.surahId
        : ((await loadPage(_page))['ayahs'] as List).first['surahId'] as int;
    if (!mounted) return;
    await showRecitationDownloads(
      context,
      reciterId: context.read<AppState>().reciterId,
      surah: surah,
    );
  }

  static const _turn = Duration(milliseconds: 280);

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label,
    bool selected,
  ) => PopupMenuItem(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 20, color: selected ? FadlColors.sage : null),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: FadlFonts.ui(
              size: 14,
              weight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        if (selected)
          const Icon(Icons.check_rounded, size: 18, color: FadlColors.sage),
      ],
    ),
  );
}

class _JumpSheet extends StatefulWidget {
  const _JumpSheet({required this.page, required this.onJump});
  final int page;
  final ValueChanged<int> onJump;

  @override
  State<_JumpSheet> createState() => _JumpSheetState();
}

class _JumpSheetState extends State<_JumpSheet> {
  late double _page = widget.page.toDouble();
  int _tab = 0;
  String _query = '';

  void _jump(int page) {
    Navigator.pop(context);
    widget.onJump(page);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.62,
          child: Column(
            children: [
              Text(
                AppLocalizations.of(context)!.jumpInMushaf,
                style: FadlFonts.heading(size: 18),
              ),
              const SizedBox(height: 10),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 0,
                    label: Text(AppLocalizations.of(context)!.pageTab),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text(AppLocalizations.of(context)!.surahTab),
                  ),
                  ButtonSegment(
                    value: 2,
                    label: Text(AppLocalizations.of(context)!.juzTabSingular),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (tabs) => setState(() => _tab = tabs.first),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: switch (_tab) {
                  0 => Column(
                    children: [
                      Text(
                        '${_number(context, _page.round())} / ${_number(context, _totalPages)}',
                        style: FadlFonts.ui(size: 22, weight: FontWeight.w700),
                      ),
                      Slider(
                        value: _page,
                        min: 1,
                        max: _totalPages.toDouble(),
                        divisions: _totalPages - 1,
                        label: _number(context, _page.round()),
                        onChanged: (v) => setState(() => _page = v),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => _jump(_page.round()),
                          child: Text(AppLocalizations.of(context)!.jump),
                        ),
                      ),
                    ],
                  ),
                  1 => Column(
                    children: [
                      LiveSearch<Map<String, dynamic>>(
                        hintText: AppLocalizations.of(context)!.searchMushaf,
                        onChanged: (v) => setState(() => _query = v),
                        search: (q) async {
                          final l = AppLocalizations.of(context)!;
                          final arabic =
                              Localizations.localeOf(context).languageCode ==
                              'ar';
                          final surahs = await QuranIndex.surahs();
                          return [
                            for (final s in surahs)
                              if (matchesSurahSearch(s, q))
                                LiveSearchSuggestion(
                                  s,
                                  l.surahName(s['nameAr'] as String),
                                  subtitle: l.pageNumber(
                                    arabic
                                        ? arNum(s['startPage'])
                                        : '${s['startPage']}',
                                  ),
                                ),
                          ];
                        },
                        onSelected: (s) => _jump(s['startPage'] as int),
                      ),
                      Expanded(
                        child: FutureBuilder<List<Map<String, dynamic>>>(
                          future: QuranIndex.surahs(),
                          builder: (context, snap) {
                            if (snap.hasError) {
                              return ErrorCard(
                                message: '${snap.error}',
                                onRetry: () => setState(() {}),
                              );
                            }
                            if (!snap.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final results = snap.data!
                                .where((s) => matchesSurahSearch(s, _query))
                                .toList();
                            return ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (context, i) {
                                final s = results[i];
                                return ListTile(
                                  title: Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.surahName(s['nameAr'] as String),
                                    style: FadlFonts.heading(size: 17),
                                  ),
                                  subtitle: Text(
                                    AppLocalizations.of(context)!.pageNumber(
                                      _number(context, s['startPage']),
                                    ),
                                  ),
                                  onTap: () => _jump(s['startPage'] as int),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  _ => GridView.builder(
                    itemCount: 30,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.1,
                        ),
                    itemBuilder: (context, i) => TextButton(
                      onPressed: () async {
                        final page = (await QuranData.load()).juzStartPage(
                          i + 1,
                        );
                        if (context.mounted) _jump(page);
                      },
                      child: Text(
                        AppLocalizations.of(
                          context,
                        )!.juzName(_number(context, i + 1)),
                      ),
                    ),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// App bar title: surah name(s) of the current page plus juz/hizb/page.
class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({required this.page, required this.palette});
  final int page;
  final _Palette palette;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _MushafReaderScreenState.loadPage(page),
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) {
          return Text(
            AppLocalizations.of(context)!.pageNumber(_number(context, page)),
          );
        }
        final names = (data['surahs'] as List)
            .map((s) => (s as Map)['nameAr'])
            .join(' • ');
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)!.surahName(names),
              style: FadlFonts.heading(size: 18, color: palette.accent),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              AppLocalizations.of(context)!.juzHizbPage(
                _number(context, data['juz']),
                _number(context, data['hizb']),
                _number(context, page),
              ),
              style: FadlFonts.ui(size: 12, color: palette.muted),
            ),
          ],
        );
      },
    );
  }
}

/// One mushaf page: surah frames, basmala and continuous justified ayahs.
class _MushafPage extends StatefulWidget {
  const _MushafPage({
    required this.data,
    required this.palette,
    required this.fontSize,
    required this.colored,
    required this.tajweed,
    required this.scheme,
    required this.dark,
    required this.selectedKey,
    required this.onAyahTap,
    required this.onEmptyTap,
  });
  final Map<String, dynamic> data;
  final _Palette palette;
  final double fontSize;
  final bool colored;
  final OfflineTajweed tajweed;
  final TajweedScheme scheme;
  final bool dark;
  final String? selectedKey;
  final void Function(Map<String, dynamic> ayah, String surahName) onAyahTap;
  final VoidCallback onEmptyTap;

  @override
  State<_MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<_MushafPage> {
  final Map<String, TapGestureRecognizer> _recognizers = {};

  @override
  void dispose() {
    for (final r in _recognizers.values) {
      r.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _recognizer(
    Map<String, dynamic> ayah,
    String surahName,
  ) {
    final r = _recognizers.putIfAbsent(
      ayah['key'] as String,
      TapGestureRecognizer.new,
    );
    r.onTap = () => widget.onAyahTap(ayah, surahName);
    return r;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<MushafLayout>(
    future: MushafLayout.load(),
    builder: (context, snapshot) => snapshot.hasData
        ? _LinePage(
            lines: snapshot.data!.lines(widget.data['page'] as int),
            data: widget.data,
            palette: widget.palette,
            fontSize: widget.fontSize,
            colored: widget.colored,
            tajweed: widget.tajweed,
            scheme: widget.scheme,
            dark: widget.dark,
            selectedKey: widget.selectedKey,
            onAyahTap: widget.onAyahTap,
            onEmptyTap: widget.onEmptyTap,
          )
        : _freeFlow(),
  );

  Widget _freeFlow() {
    final p = widget.palette;
    final ayahs = (widget.data['ayahs'] as List).cast<Map<String, dynamic>>();
    final surahs = {
      for (final s
          in (widget.data['surahs'] as List).cast<Map<String, dynamic>>())
        s['id'] as int: s,
    };

    // Split the page into runs of ayahs belonging to the same surah.
    final blocks = <Widget>[];
    var run = <Map<String, dynamic>>[];
    void flush() {
      if (run.isEmpty) return;
      final surah = surahs[run.first['surahId']]!;
      blocks.add(_ayahText(run, surah['nameAr'] as String));
      run = [];
    }

    for (final a in ayahs) {
      if (a['number'] == 1) {
        flush();
        final surah = surahs[a['surahId']]!;
        blocks.add(_SurahFrame(surah: surah, palette: p));
        final id = surah['id'] as int;
        if (id != 1 && id != 9) {
          blocks.add(
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                _basmala,
                textAlign: TextAlign.center,
                style: FadlFonts.quran(
                  size: widget.fontSize + 2,
                  color: p.accent,
                ),
              ),
            ),
          );
        }
      }
      run.add(a);
    }
    flush();

    // Keep the text width independent of the device; only the completed page
    // scales, so a narrower phone never reflows ayahs across different lines.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onEmptyTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 440,
            height: 900,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                color: p.page,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: FadlColors.gold.withValues(alpha: 0.35),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 406,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...blocks,
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            AppLocalizations.of(context)!.juzName(
                              Localizations.localeOf(context).languageCode ==
                                      'ar'
                                  ? juzNamesAr[(widget.data['juz'] as int) - 1]
                                  : _number(context, widget.data['juz']),
                            ),
                            style: FadlFonts.ui(size: 12, color: p.muted),
                          ),
                          const Spacer(),
                          Text(
                            _number(context, widget.data['page']),
                            style: FadlFonts.ui(
                              size: 13,
                              weight: FontWeight.w700,
                              color: p.accent,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            AppLocalizations.of(context)!.surahName(
                              surahs.values.last['nameAr'] as String,
                            ),
                            style: FadlFonts.ui(size: 12, color: p.muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ayahText(List<Map<String, dynamic>> run, String surahName) {
    final p = widget.palette;
    final base = FadlFonts.quran(
      size: widget.fontSize,
      color: p.text,
      height: 2.1,
    );
    return Text.rich(
      TextSpan(
        children: [
          for (final a in run)
            // Recognizers only fire on leaf spans, so each child gets it.
            TextSpan(
              style: a['key'] == widget.selectedKey
                  ? base.copyWith(backgroundColor: p.highlight)
                  : null,
              children: [
                if (widget.colored &&
                    widget.tajweed.pieces(a['key'] as String) != null)
                  for (final piece in widget.tajweed.pieces(
                    a['key'] as String,
                  )!)
                    TextSpan(
                      text: piece.text,
                      style:
                          piece.rule == null ||
                              widget.scheme.colorFor(
                                    piece.rule,
                                    dark: widget.dark,
                                  ) ==
                                  null
                          ? null
                          : TextStyle(
                              color: widget.scheme.colorFor(
                                piece.rule,
                                dark: widget.dark,
                              ),
                            ),
                      recognizer: _recognizer(a, surahName),
                    )
                else
                  TextSpan(
                    text: '${a['text']}',
                    recognizer: _recognizer(a, surahName),
                  ),
                TextSpan(text: ' ', recognizer: _recognizer(a, surahName)),
                TextSpan(
                  text: '${ayahMarker(a['number'] as int)} ',
                  style: const TextStyle(color: FadlColors.gold),
                  recognizer: _recognizer(a, surahName),
                ),
              ],
            ),
        ],
      ),
      style: base,
      textAlign: TextAlign.justify,
      textDirection: TextDirection.rtl,
    );
  }
}

class _LinePage extends StatelessWidget {
  const _LinePage({
    required this.lines,
    required this.data,
    required this.palette,
    required this.fontSize,
    required this.colored,
    required this.tajweed,
    required this.scheme,
    required this.dark,
    required this.selectedKey,
    required this.onAyahTap,
    required this.onEmptyTap,
  });

  final List<MushafLine> lines;
  final Map<String, dynamic> data;
  final _Palette palette;
  final double fontSize;
  final bool colored;
  final OfflineTajweed tajweed;
  final TajweedScheme scheme;
  final bool dark;
  final String? selectedKey;
  final void Function(Map<String, dynamic>, String) onAyahTap;
  final VoidCallback onEmptyTap;

  Map<MushafToken, List<TextSpan>> _coloredWords() {
    if (!colored) return {};
    final byKey = <String, List<MushafToken>>{};
    for (final line in lines) {
      for (final token in line.tokens) {
        if (!token.isEnd) {
          byKey.putIfAbsent(token.ayahKey, () => []).add(token);
        }
      }
    }
    final coloredWords = <MushafToken, List<TextSpan>>{};
    for (final entry in byKey.entries) {
      final pieces = tajweed.pieces(entry.key);
      if (pieces == null) continue;
      final letters = <(String, String?)>[];
      for (final piece in pieces) {
        for (final rune in piece.text.runes) {
          final letter = String.fromCharCode(rune);
          if (letter.trim().isNotEmpty) letters.add((letter, piece.rule));
        }
      }
      final expected = entry.value
          .map((token) => token.text!.replaceAll(RegExp(r'\s+'), ''))
          .join();
      if (letters.map((letter) => letter.$1).join() != expected) continue;
      var offset = 0;
      for (final token in entry.value) {
        final spans = <TextSpan>[];
        for (final rune in token.text!.runes) {
          final letter = String.fromCharCode(rune);
          if (letter.trim().isEmpty) {
            spans.add(TextSpan(text: letter));
          } else {
            final rule = letters[offset++].$2;
            spans.add(
              TextSpan(
                text: letter,
                style: TextStyle(color: scheme.colorFor(rule, dark: dark)),
              ),
            );
          }
        }
        coloredWords[token] = spans;
      }
    }
    return coloredWords;
  }

  Widget _word(
    MushafToken token,
    TextStyle style,
    Map<String, Map<String, dynamic>> ayahs,
    Map<int, Map<String, dynamic>> surahs,
    Map<MushafToken, List<TextSpan>> colors,
  ) {
    final ayah = ayahs[token.ayahKey]!;
    final selected = selectedKey == token.ayahKey;
    final text = token.isEnd ? ayahMarker(ayah['number'] as int) : token.text!;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          onAyahTap(ayah, surahs[ayah['surahId']]!['nameAr'] as String),
      child: Text.rich(
        TextSpan(
          text: token.isEnd ? text : null,
          children: token.isEnd
              ? null
              : colors[token] ?? [TextSpan(text: text)],
        ),
        textDirection: TextDirection.rtl,
        maxLines: 1,
        softWrap: false,
        style: style.copyWith(
          color: token.isEnd ? FadlColors.gold : palette.text,
          backgroundColor: selected ? palette.highlight : null,
        ),
      ),
    );
  }

  Widget _textLine(
    MushafLine line,
    double height,
    double width,
    Map<String, Map<String, dynamic>> ayahs,
    Map<int, Map<String, dynamic>> surahs,
    Map<MushafToken, List<TextSpan>> colors,
  ) {
    if (line.tokens.isEmpty) return SizedBox(height: height, width: width);
    final size = (height * 0.43 + (fontSize - 24) * 0.5).clamp(15.0, 48.0);
    final style = FadlFonts.quran(size: size, height: 1.85);
    final words = [
      for (final token in line.tokens)
        _word(token, style, ayahs, surahs, colors),
    ];
    final painter = TextPainter(textDirection: TextDirection.rtl);
    var naturalWidth = 0.0;
    for (final token in line.tokens) {
      painter.text = TextSpan(
        text: token.isEnd
            ? ayahMarker(ayahs[token.ayahKey]!['number'] as int)
            : token.text,
        style: style,
      );
      painter.layout();
      naturalWidth += painter.width;
    }
    painter.dispose();
    final shortLine =
        line.tokens.length < 7 && line.tokens.any((token) => token.isEnd);
    final rowWidth = shortLine && naturalWidth < width * 0.72
        ? naturalWidth + math.max(0, line.tokens.length - 1) * 8
        : math.max(
            width,
            naturalWidth + math.max(0, line.tokens.length - 1) * 3,
          );
    return SizedBox(
      height: height,
      width: width,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: SizedBox(
          width: rowWidth,
          child: Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: words,
          ),
        ),
      ),
    );
  }

  Widget _slot(
    MushafLine line,
    double height,
    double width,
    Map<String, Map<String, dynamic>> ayahs,
    Map<int, Map<String, dynamic>> surahs,
    Map<MushafToken, List<TextSpan>> colors,
  ) {
    if (line.surahId != null) {
      return SizedBox(
        height: height,
        child: _SurahFrame(
          surah: surahs[line.surahId]!,
          palette: palette,
          compact: true,
          showBasmala: line.isBasmala,
        ),
      );
    }
    if (line.isBasmala) {
      return SizedBox(
        height: height,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _basmala,
              textDirection: TextDirection.rtl,
              style: FadlFonts.quran(
                size: height * 0.49,
                color: palette.accent,
                height: 1.5,
              ),
            ),
          ),
        ),
      );
    }
    return _textLine(line, height, width, ayahs, surahs, colors);
  }

  @override
  Widget build(BuildContext context) {
    final ayahs = {
      for (final ayah in (data['ayahs'] as List).cast<Map<String, dynamic>>())
        ayah['key'] as String: ayah,
    };
    final surahs = {
      for (final surah in (data['surahs'] as List).cast<Map<String, dynamic>>())
        surah['id'] as int: surah,
    };
    final colors = _coloredWords();
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = (constraints.maxHeight - 30) / 15;
        final width = constraints.maxWidth - 20;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onEmptyTap,
          child: Container(
            color: palette.page,
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
            child: Column(
              children: [
                for (final line in lines)
                  _slot(line, height, width, ayahs, surahs, colors),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        AppLocalizations.of(context)!.juzName(
                          Localizations.localeOf(context).languageCode == 'ar'
                              ? juzNamesAr[(data['juz'] as int) - 1]
                              : _number(context, data['juz']),
                        ),
                        style: FadlFonts.ui(size: 11, color: palette.muted),
                      ),
                      const Spacer(),
                      Text(
                        _number(context, data['page']),
                        style: FadlFonts.ui(size: 13, color: palette.accent),
                      ),
                      const Spacer(),
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.surahName(surahs.values.last['nameAr'] as String),
                        style: FadlFonts.ui(size: 11, color: palette.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SurahFrame extends StatelessWidget {
  const _SurahFrame({
    required this.surah,
    required this.palette,
    this.compact = false,
    this.showBasmala = false,
  });
  final Map<String, dynamic> surah;
  final _Palette palette;
  final bool compact;
  final bool showBasmala;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: compact
          ? const EdgeInsets.symmetric(vertical: 2)
          : const EdgeInsets.only(top: 8, bottom: 4),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 14,
        vertical: compact ? 2 : 10,
      ),
      decoration: BoxDecoration(
        color: palette.frame,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: FadlColors.gold.withValues(alpha: 0.7),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // A compact frame fills one mushaf line, whose height follows the
          // screen: the title scales down to fit short lines.
          if (compact)
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  AppLocalizations.of(
                    context,
                  )!.surahName(surah['nameAr'] as String),
                  maxLines: 1,
                  style: FadlFonts.quran(size: 15, color: palette.accent),
                ),
              ),
            )
          else
            Row(
              children: [
                Text(
                  AppLocalizations.of(
                    context,
                  )!.surahOrder(_number(context, surah['id'])),
                  style: FadlFonts.ui(size: 11.5, color: palette.muted),
                ),
                Expanded(
                  child: Text(
                    AppLocalizations.of(
                      context,
                    )!.surahName(surah['nameAr'] as String),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: FadlFonts.quran(size: 20, color: palette.accent),
                  ),
                ),
                Text(
                  AppLocalizations.of(
                    context,
                  )!.surahVerses(_number(context, surah['ayahCount'])),
                  style: FadlFonts.ui(size: 11.5, color: palette.muted),
                ),
              ],
            ),
          if (showBasmala)
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _basmala,
                  textDirection: TextDirection.rtl,
                  style: FadlFonts.quran(
                    size: 18,
                    color: palette.accent,
                    height: 1.3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom sheet for a tapped ayah: tafsir with edition chips and actions.
class _AyahSheet extends StatefulWidget {
  const _AyahSheet({
    required this.ayah,
    required this.surahName,
    required this.onMarkRead,
    required this.onListen,
  });
  final Map<String, dynamic> ayah;
  final String surahName;
  final Future<void> Function() onMarkRead;
  final Future<void> Function() onListen;

  @override
  State<_AyahSheet> createState() => _AyahSheetState();
}

class _AyahSheetState extends State<_AyahSheet> {
  static const _onlineEditions = {
    'ar.muyassar': 'الميسر',
    'ar.saddi': 'السعدي',
    'ar.ibnkathir': 'ابن كثير',
  };
  static final _localEditions = {
    for (final e in offlineTafsirEditions) e.slug: e.nameAr,
  };
  Map<String, String> get _editions =>
      Api.hasBackend ? _onlineEditions : _localEditions;
  final Map<String, Future<Map<String, dynamic>>> _tafsir = {};
  late String _edition;

  @override
  void initState() {
    super.initState();
    final preferred =
        context.read<AppState>().settings['tafsirSlug'] as String?;
    _edition = _editions.containsKey(preferred) ? preferred! : 'ar.muyassar';
  }

  Future<Map<String, dynamic>> _load(String edition) =>
      _tafsir.putIfAbsent(edition, () async {
        try {
          if (!Api.hasBackend) {
            return await OfflineTafsir.instance.ayahTafsir(
                  widget.ayah['key'] as String,
                  edition,
                ) ??
                {'notDownloaded': true};
          }
          return await Api.instance.get(
                '/quran/ayahs/${widget.ayah['key']}/tafsir',
                {'edition': edition},
              )
              as Map<String, dynamic>;
        } catch (_) {
          _tafsir.remove(edition);
          rethrow;
        }
      });

  String get _ref => AppLocalizations.of(
    context,
  )!.surahVerse(widget.surahName, _number(context, widget.ayah['number']));

  Future<void> _bookmark() async {
    try {
      if (Api.hasBackend) {
        await Api.instance.post('/me/bookmarks', {
          'ayahKey': widget.ayah['key'],
        });
      } else {
        await LocalUserData.instance.addBookmark(widget.ayah['key'] as String);
      }
      if (mounted) {
        showToast(context, AppLocalizations.of(context)!.bookmarkSaved);
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    } on LocalDataException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  Future<void> _markRead() async {
    try {
      await widget.onMarkRead();
      if (mounted) {
        showToast(context, AppLocalizations.of(context)!.readingPositionSaved);
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final a = widget.ayah;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  NumberBadge(a['number'] as int, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_ref, style: FadlFonts.heading(size: 17)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? FadlColors.darkSurfaceHigh
                              : FadlColors.goldSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${a['text']} ${ayahMarker(a['number'] as int)}',
                          textAlign: TextAlign.center,
                          style: FadlFonts.quran(
                            size: 22,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final e in _editions.entries)
                              PillChip(
                                label: e.value,
                                selected: e.key == _edition,
                                onTap: () => setState(() => _edition = e.key),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<Map<String, dynamic>>(
                        key: ValueKey(_edition),
                        future: _load(_edition),
                        builder: (context, snap) {
                          if (snap.hasError) {
                            return ErrorCard(
                              message: '${snap.error}',
                              onRetry: () => setState(() {}),
                            );
                          }
                          if (!snap.hasData) {
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (snap.data!['notDownloaded'] == true) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.tafsirNotDownloaded,
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => const SettingsScreen(),
                                      ),
                                    );
                                    _tafsir.remove(_edition);
                                    if (mounted) setState(() {});
                                  },
                                  icon: const Icon(Icons.download_outlined),
                                  label: Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.offlineTafsirSettings,
                                  ),
                                ),
                              ],
                            );
                          }
                          final edition = snap.data!['edition'] as Map;
                          final text = snap.data!['text'] as String?;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                edition['nameAr'] as String,
                                style: FadlFonts.ui(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: FadlColors.sage,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                text ??
                                    AppLocalizations.of(
                                      context,
                                    )!.tafsirUnavailable,
                                style: FadlFonts.ui(
                                  size: 15.5,
                                  height: 1.9,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _action(
                    Icons.headphones_rounded,
                    AppLocalizations.of(context)!.listen,
                    () {
                      Navigator.pop(context);
                      widget.onListen();
                    },
                  ),
                  _action(
                    Icons.bookmark_add_outlined,
                    AppLocalizations.of(context)!.saveBookmark,
                    _bookmark,
                  ),
                  _action(
                    Icons.share_outlined,
                    AppLocalizations.of(context)!.share,
                    () {
                      SharePlus.instance.share(
                        ShareParams(
                          text:
                              '﴿${a['text']}﴾\n[$_ref]\n\n${AppLocalizations.of(context)!.sharedFromFadl}',
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _markRead,
                icon: const Icon(Icons.done_all_rounded),
                label: Text(AppLocalizations.of(context)!.markRead),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: FadlFonts.ui(size: 13, weight: FontWeight.w700),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    ),
  );
}

class _LocalBookmarksSheet extends StatefulWidget {
  const _LocalBookmarksSheet({required this.onOpen});
  final void Function(int page, String key) onOpen;

  @override
  State<_LocalBookmarksSheet> createState() => _LocalBookmarksSheetState();
}

class _LocalBookmarksSheetState extends State<_LocalBookmarksSheet> {
  late Future<List<Map<String, dynamic>>> _items = LocalUserData.instance
      .bookmarks();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.65,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              AppLocalizations.of(context)!.myBookmarks,
              style: FadlFonts.heading(size: 20),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _items,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorCard(message: '${snapshot.error}');
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final bookmarks = snapshot.data!;
                if (bookmarks.isEmpty) {
                  return Center(
                    child: Text(AppLocalizations.of(context)!.noBookmarks),
                  );
                }
                return FutureBuilder<QuranData>(
                  future: QuranData.load(),
                  builder: (context, quran) {
                    if (quran.hasError) {
                      return ErrorCard(message: '${quran.error}');
                    }
                    if (!quran.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return ListView.builder(
                      itemCount: bookmarks.length,
                      itemBuilder: (context, index) {
                        final key = bookmarks[index]['ayahKey'] as String;
                        final ayah = quran.data!.ayah(key);
                        return ListTile(
                          title: Text(
                            ayah == null
                                ? key
                                : AppLocalizations.of(context)!.surahAndVerse(
                                    quran.data!.surahs[(ayah['surahId']
                                                as int) -
                                            1]['nameAr']
                                        as String,
                                    _number(context, ayah['number']),
                                  ),
                          ),
                          subtitle: Text(key),
                          onTap: ayah == null
                              ? null
                              : () => widget.onOpen(ayah['page'] as int, key),
                          trailing: IconButton(
                            tooltip: AppLocalizations.of(
                              context,
                            )!.deleteBookmark,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await LocalUserData.instance.removeBookmark(key);
                              if (mounted) {
                                setState(
                                  () => _items = LocalUserData.instance
                                      .bookmarks(),
                                );
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
