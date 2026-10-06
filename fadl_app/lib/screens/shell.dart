import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../widgets/adaptive_layout.dart';

import 'athkar/athkar_screen.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import 'prayer/prayer_times_screen.dart';
import 'quran/mushaf_index_screen.dart';

/// Tabs الرئيسية / المصحف / الأذكار / المواقيت / المزيد: a bottom bar on
/// phones, a side rail on wide windows.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static AppShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<AppShellState>();

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int index = 0;
  final Set<int> _visited = {0};

  /// Keeps every tab's state when rotating between the bar and the rail.
  final _tabsKey = GlobalKey();

  void goTo(int tab) => setState(() {
    index = tab;
    _visited.add(tab);
  });

  @override
  Widget build(BuildContext context) {
    final l =
        (AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('ar')));
    final destinations = [
      (Icons.home_outlined, Icons.home_rounded, l.home),
      (Icons.menu_book_outlined, Icons.menu_book_rounded, l.mushaf),
      (Icons.auto_awesome_outlined, Icons.auto_awesome, l.athkar),
      (Icons.schedule_outlined, Icons.schedule, l.prayerTimes),
      (Icons.grid_view_outlined, Icons.grid_view_rounded, l.more),
    ];
    final tabs = IndexedStack(
      key: _tabsKey,
      index: index,
      children: [
        for (final (tab, screen) in const [
          (0, HomeScreen()),
          (1, MushafIndexScreen()),
          (2, AthkarScreen()),
          (3, PrayerTimesScreen()),
          (4, MoreScreen()),
        ])
          if (_visited.contains(tab)) screen else const SizedBox.shrink(),
      ],
    );
    // Wide windows (iPad landscape) keep the tabs in a side rail.
    if (useSideNavigation(context)) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              child: NavigationRail(
                selectedIndex: index,
                onDestinationSelected: goTo,
                labelType: NavigationRailLabelType.all,
                groupAlignment: 0,
                destinations: [
                  for (final (icon, selected, label) in destinations)
                    NavigationRailDestination(
                      icon: Icon(icon),
                      selectedIcon: Icon(selected),
                      label: Text(label),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: tabs),
          ],
        ),
      );
    }
    return Scaffold(
      body: tabs,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: goTo,
        destinations: [
          for (final (icon, selected, label) in destinations)
            NavigationDestination(
              icon: Icon(icon),
              selectedIcon: Icon(selected),
              label: label,
            ),
        ],
      ),
    );
  }
}
