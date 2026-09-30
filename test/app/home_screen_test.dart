import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammarstudy/app/home/home_screen.dart';
import 'package:grammarstudy/app/home/home_tabs.dart';
import 'package:grammarstudy/features/games/presentation/games_tab.dart';
import 'package:grammarstudy/features/grammar/presentation/grammar_tab.dart';
import 'package:grammarstudy/features/help/presentation/help_tab.dart';
import 'package:grammarstudy/features/information/presentation/information_tab.dart';
import 'package:grammarstudy/features/sentence/presentation/sentence_tab.dart';
import 'package:grammarstudy/features/structure/presentation/structure_tab.dart';

import '../helpers/test_database.dart';

void main() {
  // package_info_plus has no platform implementation under flutter_test, so the
  // contact form's package lookup must be stubbed on its method channel.
  const packageInfoChannel = MethodChannel(
    'dev.fluttercommunity.plus/package_info',
  );

  void stubPackageInfo() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageInfoChannel, (call) async {
          switch (call.method) {
            case 'getPackageName':
              return 'com.stefanronnkvist.paid.grammarstudy';
            case 'getPackageVersion':
              return '1.0.0';
            case 'getPackageBuildNumber':
              return '1';
            default:
              return null;
          }
        });
  }

  setUpAll(() async {
    await seedTestDatabase();
    stubPackageInfo();
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(packageInfoChannel, null);
    await disposeTestDatabase();
  });

  Widget buildSubject() {
    return MaterialApp(
      home: HomeScreen(themeMode: ThemeMode.system, onThemeModeChanged: (_) {}),
    );
  }

  group('homeTabLabels', () {
    test('lists the six study areas in display order', () {
      expect(homeTabLabels, [
        'Games',
        'Grammar',
        'Structure',
        'Sentence',
        'Help',
        'Information',
      ]);
    });
  });

  group('HomeScreen', () {
    testWidgets('shows the app title', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.text('Grammar Study'), findsOneWidget);
    });

    testWidgets('renders every top-level tab label', (tester) async {
      await tester.pumpWidget(buildSubject());
      for (final label in homeTabLabels) {
        expect(find.text(label), findsWidgets, reason: 'missing $label');
      }
    });

    testWidgets('opens on the Games tab', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      // The games inner tabs identify the Games tab as selected.
      expect(find.text('Crossword'), findsWidgets);
      expect(find.text('Slide'), findsWidgets);
      expect(find.text('Drag'), findsWidgets);
    });

    testWidgets('exposes theme and diagnostics actions', (tester) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byTooltip('Theme'), findsOneWidget);
      expect(find.byTooltip('DB diagnostics'), findsOneWidget);
    });

    testWidgets('theme menu offers system, light, and dark', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.byTooltip('Theme'));
      await tester.pumpAndSettle();

      expect(find.text('System theme'), findsOneWidget);
      expect(find.text('Light theme'), findsOneWidget);
      expect(find.text('Dark theme'), findsOneWidget);
    });

    testWidgets('selecting a theme reports the new mode', (tester) async {
      ThemeMode? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            themeMode: ThemeMode.system,
            onThemeModeChanged: (mode) => selected = mode,
          ),
        ),
      );

      await tester.tap(find.byTooltip('Theme'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark theme'));
      await tester.pumpAndSettle();

      expect(selected, ThemeMode.dark);
    });

    testWidgets('switches to the Help tab and shows guidance', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.tap(find.text('Help'));
      await tester.pumpAndSettle();

      expect(find.text('Getting Started'), findsOneWidget);
      expect(find.text('Games Tab'), findsOneWidget);
    });

    testWidgets('navigates back to Games after visiting another tab', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('Help'));
      await tester.pumpAndSettle();
      expect(find.text('Getting Started'), findsOneWidget);

      await tester.tap(find.text('Games'));
      await tester.pumpAndSettle();
      expect(find.text('Crossword'), findsWidgets);
    });
  });

  group('HomeTabView', () {
    testWidgets('builds one widget per study area', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Renders through HomeScreen so the tab bar is available. TabBarView
      // mounts only the visible pane, so each area is checked by navigating
      // to its tab. This also avoids the Submissions download.
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            themeMode: ThemeMode.system,
            onThemeModeChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> openTab(String label, Type expected) async {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.byType(expected), findsOneWidget);
      }

      expect(find.byType(GamesTab), findsOneWidget);
      await openTab('Grammar', GrammarTab);
      await openTab('Structure', StructureTab);
      await openTab('Sentence', SentenceTab);
      await openTab('Help', HelpTab);
      await openTab('Information', InformationTab);
    });
  });

  group('Information tab', () {
    testWidgets('groups contact and submissions views', (tester) async {
      // The contact form needs a taller viewport than the 800x600 default.
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: InformationTab()));
      await tester.pumpAndSettle();

      expect(find.text('Contact Us'), findsOneWidget);
      expect(find.text('Submissions'), findsOneWidget);
    });
  });
}
