import 'package:fadl/core/app_state.dart';
import 'package:fadl/screens/shell.dart';
import 'package:fadl/widgets/adaptive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppState> showShell(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState();
    await tester.runAsync(state.load);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          builder: (context, child) => TabletFrame(child: child!),
          home: const AppShell(),
        ),
      ),
    );
    await tester.pump();
    return state;
  }

  testWidgets('phones keep the bottom bar at full width', (tester) async {
    await showShell(tester, const Size(390, 844));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.getSize(find.byType(AppShell)).width, 390);
  });

  testWidgets('iPad portrait uses the bottom bar across the screen', (
    tester,
  ) async {
    await showShell(tester, const Size(820, 1180));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.getSize(find.byType(AppShell)).width, 820);
  });

  testWidgets('iPad landscape centres the app with a side rail', (
    tester,
  ) async {
    await showShell(tester, const Size(1366, 1024));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    final shell = tester.getRect(find.byType(AppShell));
    expect(shell.width, maxAppWidth);
    expect(shell.center.dx, 683);
    // Layouts that measure the screen see the frame, not the whole iPad.
    expect(
      MediaQuery.sizeOf(tester.element(find.byType(AppShell))).width,
      maxAppWidth,
    );

    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pump();
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      4,
    );
  });

  testWidgets('rotating keeps the selected tab', (tester) async {
    await showShell(tester, const Size(820, 1180));
    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pump();
    tester.view.physicalSize = const Size(1180, 820);
    await tester.pump();
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      4,
    );
  });
}
