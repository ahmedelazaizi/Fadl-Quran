import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import 'athkar/athkar_screen.dart';
import 'home_screen.dart';
import 'more_screen.dart';
import 'prayer/prayer_times_screen.dart';
import 'quran/mushaf_index_screen.dart';

/// Bottom navigation: الرئيسية / المصحف / الأذكار / المواقيت / المزيد.
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

  void goTo(int tab) => setState(() {
    index = tab;
    _visited.add(tab);
  });

  @override
  Widget build(BuildContext context) {
    final l =
        (AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('ar')));
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          if (_visited.contains(0))
            const HomeScreen()
          else
            const SizedBox.shrink(),
          if (_visited.contains(1))
            const MushafIndexScreen()
          else
            const SizedBox.shrink(),
          if (_visited.contains(2))
            const AthkarScreen()
          else
            const SizedBox.shrink(),
          if (_visited.contains(3))
            const PrayerTimesScreen()
          else
            const SizedBox.shrink(),
          if (_visited.contains(4))
            const MoreScreen()
          else
            const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: goTo,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: l.home,
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: l.mushaf,
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: l.athkar,
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: l.prayerTimes,
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: l.more,
          ),
        ],
      ),
    );
  }
}
