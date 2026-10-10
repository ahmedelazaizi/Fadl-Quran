// End-to-end walkthrough of the whole app, shared by the on-device
// integration test (integration_test/app_e2e_test.dart) and the host run
// (test/app_e2e_test.dart).
//
// It starts the real app, opens every tab and every screen listed under
// «المزيد», and on each one taps every visible button, switch, menu and list
// row, returning to the screen after each tap. Every framework error raised
// along the way (exceptions, layout overflows, failed assertions) is
// collected with the screen and control that caused it.

import 'package:fadl/core/app_state.dart';
import 'package:fadl/l10n/app_localizations.dart';
import 'package:fadl/main.dart';
import 'package:fadl/screens/shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// One problem found by the walkthrough.
class E2eIssue {
  E2eIssue(this.where, this.error);
  final String where;
  final String error;

  @override
  String toString() => '[$where] $error';
}

/// Report of a walkthrough: screens opened, controls tapped, problems found.
class E2eReport {
  final screens = <String>[];
  var taps = 0;
  final issues = <E2eIssue>[];
  final ignored = <E2eIssue>[];

  String summary() => [
    'Screens opened (${screens.length}): ${screens.join(', ')}',
    'Controls tapped: $taps',
    'Problems: ${issues.length}',
    for (final issue in issues) '  - $issue',
    if (ignored.isNotEmpty)
      'Ignored (platform plugins missing on the host): ${ignored.length}',
  ].join('\n');
}

typedef Wait = Future<void> Function(WidgetTester tester);

class E2eWalkthrough {
  E2eWalkthrough(this.tester, {required this.wait, this.ignore});

  final WidgetTester tester;

  /// Lets the app settle after an action: on the host this advances the
  /// fake clock and lets real IO finish; on a device it waits real time.
  final Wait wait;

  /// Errors to set aside instead of reporting (host-only plugin gaps).
  final bool Function(String error)? ignore;

  final report = E2eReport();
  String _where = 'startup';
  FlutterExceptionHandler? _previous;

  void _record(String error) {
    final issue = E2eIssue(_where, error);
    if (ignore?.call(error) ?? false) {
      report.ignored.add(issue);
    } else if (!report.issues.any(
      (i) => i.where == issue.where && i.error == issue.error,
    )) {
      report.issues.add(issue);
    }
  }

  void _listen() {
    _previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString().split('\n').take(3).join(' ');
      // The full report names the widget and source line that failed.
      debugPrint(
        'E2E problem at $_where:\n${details.toString().split('\n').take(14).join('\n')}',
      );
      final widget = details.context?.toDescription() ?? '';
      _record('$text${widget.isEmpty ? '' : ' ($widget)'}');
    };
  }

  void _stopListening() => FlutterError.onError = _previous;

  void _collect() {
    final error = tester.takeException();
    if (error != null) _record('$error'.split('\n').take(3).join(' '));
  }

  Future<void> _settle() async {
    await wait(tester);
    _collect();
  }

  /// Toasts float over the bottom of the screen for a few seconds; a user
  /// waits for them, so they are dismissed before each tap.
  void _dismissToasts() => tester
      .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
      .removeCurrentSnackBar();

  NavigatorState get _navigator =>
      tester.state<NavigatorState>(find.byType(Navigator).first);

  late final AppLocalizations _l;

  /// Starts the app as `main()` does and runs the whole walkthrough.
  Future<E2eReport> run(AppState state) async {
    _listen();
    try {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: state, child: const FadlApp()),
      );
      await _settle();
      expect(find.byType(AppShell), findsOneWidget);
      _l = AppLocalizations.of(tester.element(find.byType(AppShell)))!;
      await _walkTabs();
      await _walkMoreScreens();
    } finally {
      _stopListening();
    }
    return report;
  }

  Future<void> _goToTab(int index) async {
    final bar = find.byType(NavigationBar);
    final destinations = find.descendant(
      of: bar,
      matching: find.byType(NavigationDestination),
    );
    await tester.tap(destinations.at(index));
    await _settle();
  }

  Future<void> _walkTabs() async {
    final l = _l;
    final tabs = [l.home, l.mushaf, l.athkar, l.prayerTimes, l.more];
    for (var i = 0; i < tabs.length; i++) {
      _where = 'tab ${tabs[i]}';
      report.screens.add(tabs[i]);
      await _goToTab(i);
      await _sweep(reopen: () => _goToTab(i));
      // Leave the tab on its root screen for the next one.
      _navigator.popUntil((route) => route.isFirst);
      await _settle();
    }
  }

  Future<void> _walkMoreScreens() async {
    final l = _l;
    final entries = [
      l.prayerTracker,
      l.hijriCalendar,
      l.fastingTracker,
      l.hajjUmrah,
      l.zakatCalculator,
      l.hadithLibrary,
      l.quranAssistant,
      l.audioLibrary,
      l.library,
      l.downloads,
      l.tasbeehElectronic,
      l.quranCompletion,
      l.qiblaDirection,
      l.ramadan,
      l.parentDua,
      l.settings,
    ];
    for (final entry in entries) {
      _where = 'more › $entry';
      report.screens.add(entry);
      Future<bool> open() async {
        _navigator.popUntil((route) => route.isFirst);
        await _goToTab(4);
        final tile = find.text(entry);
        if (tile.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            tile,
            200,
            scrollable: find.byType(Scrollable).last,
          );
        }
        await tester.ensureVisible(tile.first);
        _dismissToasts();
        await tester.pump();
        await tester.tap(tile.first);
        await _settle();
        return _navigator.canPop();
      }

      if (!await open()) {
        _record('could not open the screen');
        continue;
      }
      await _sweep(reopen: open);
      _navigator.popUntil((route) => route.isFirst);
      await _settle();
    }
  }

  /// Controls a user can press: buttons, switches, menus and tappable rows.
  /// The tab bar and text fields are left out (tabs are walked separately).
  Finder get _controls => find.byWidgetPredicate((widget) {
    if (widget is ButtonStyleButton) return widget.onPressed != null;
    if (widget is IconButton) return widget.onPressed != null;
    if (widget is FloatingActionButton) return widget.onPressed != null;
    if (widget is Switch) return widget.onChanged != null;
    if (widget is Checkbox) return widget.onChanged != null;
    if (widget is ListTile) return widget.onTap != null;
    if (widget is PopupMenuButton) return widget.enabled;
    if (widget is DropdownButton) {
      // Generic callbacks cannot be read through DropdownButton<dynamic>.
      return (widget as dynamic).onChanged != null;
    }
    if (widget is ChoiceChip || widget is FilterChip) return true;
    if (widget is InkWell) {
      return widget.onTap != null || widget.onLongPress != null;
    }
    if (widget is GestureDetector) return widget.onTap != null;
    return false;
  });

  bool _excluded(Element element) {
    var excluded = false;
    element.visitAncestorElements((ancestor) {
      final w = ancestor.widget;
      if (w is NavigationBar || w is NavigationRail || w is EditableText) {
        excluded = true;
        return false;
      }
      // A control inside another control is tapped through its parent.
      if (w is ButtonStyleButton ||
          w is IconButton ||
          w is ListTile ||
          w is PopupMenuButton ||
          w is DropdownButton) {
        excluded = true;
        return false;
      }
      return true;
    });
    final w = element.widget;
    if (w is BackButton) return true;
    if (w is IconButton) {
      final tip = w.tooltip;
      if (tip != null && (tip == _l.back || tip == 'Back')) return true;
    }
    return excluded;
  }

  String _describe(Element element) {
    final w = element.widget;
    String? label;
    if (w is IconButton) label = w.tooltip;
    final texts = <String>[];
    void collect(Element e) {
      final widget = e.widget;
      if (widget is Text && widget.data != null) texts.add(widget.data!);
      if (widget is Icon && widget.icon != null && texts.isEmpty) {
        texts.add('icon U+${widget.icon!.codePoint.toRadixString(16)}');
      }
      if (texts.length < 2) e.visitChildElements(collect);
    }

    collect(element);
    label ??= texts.isEmpty ? null : texts.take(2).join(' / ');
    return '${w.runtimeType}${label == null ? '' : ' «$label»'}';
  }

  /// Taps every control on the current screen, one at a time, coming back
  /// to the screen after each one.
  Future<void> _sweep({required Future<Object?> Function() reopen}) async {
    final screen = _where;
    final home = ModalRoute.of(
      tester.element(find.byType(Scaffold).hitTestable().last),
    );
    var index = 0;
    final seen = <String>{};
    for (var guard = 0; guard < 120; guard++) {
      final candidates = _controls
          .hitTestable()
          .evaluate()
          .where((e) => !_excluded(e))
          .toList();
      if (index >= candidates.length) break;
      final target = candidates[index++];
      final name = _describe(target);
      // Repeated rows (a list of 114 surahs) are sampled, not all tapped.
      final key = '$name@${candidates.length}';
      if (!seen.add(key) && seen.length > 40) continue;
      _where = '$screen › $name';
      _dismissToasts();
      try {
        await tester.tap(
          find.byElementPredicate((e) => identical(e, target)),
          warnIfMissed: false,
        );
        report.taps++;
        await _settle();
      } catch (e) {
        _record('tap failed: ${'$e'.split('\n').first}');
      }
      // Close whatever the tap opened (page, dialog, sheet, menu).
      if (home != null && !home.isCurrent) {
        if (home.isActive) {
          _navigator.popUntil((route) => route == home);
        } else {
          await reopen();
        }
        await _settle();
      }
    }
    _where = screen;
  }
}

/// Plugins that only exist on a phone; on the host their calls fail.
bool hostOnlyPluginError(String error) =>
    error.contains('MissingPluginException') ||
    error.contains('No implementation found for method');

void printReport(E2eReport report) => debugPrint(report.summary());
