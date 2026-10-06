import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivduck/core/models.dart';
import 'package:vivduck/core/theme.dart';
import 'package:vivduck/report_teacher/teacher_screen.dart';

Map<String, dynamic> _loadFixture() {
  const contractPath = '../shared/contracts/04_teacher_summary.json';
  const assetPath = 'assets/fixtures/04_teacher_summary.json';

  final contractFile = File(contractPath);
  if (contractFile.existsSync()) {
    return jsonDecode(contractFile.readAsStringSync()) as Map<String, dynamic>;
  }
  final assetFile = File(assetPath);
  return jsonDecode(assetFile.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fixture = _loadFixture();
  final summary =
      TeacherSummary.fromJson(fixture['response'] as Map<String, dynamic>);

  Widget buildTestable({Widget? child, Size size = const Size(1280, 800)}) {
    return MaterialApp(
      key: UniqueKey(),
      theme: buildTheme(Brightness.light),
      initialRoute: '/teacher',
      routes: {
        '/': (_) => const Scaffold(body: Text('Home Student View')),
        '/teacher': (_) => MediaQuery(
              data: MediaQueryData(size: size),
              child: child ?? TeacherScreen(summaryFuture: Future.value(summary)),
            ),
      },
    );
  }

  group('TeacherScreen', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pump();
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    Future<void> cleanup(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    }

    testWidgets('renders all required elements at 1280px wide', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestable(size: const Size(1280, 800)));
      await pumpScreen(tester);

      // 1. Header with "Student view" on the right and "Sample class data" chip
      expect(find.text('Student view'), findsOneWidget);
      expect(find.text('Sample class data'), findsOneWidget);

      // 2. Title: assignment name & "N students have defended their submission"
      expect(find.text(summary.assignment), findsOneWidget);
      expect(
        find.text('${summary.sessions.length} students have defended their submission'),
        findsOneWidget,
      );

      // 3. Three tiles computed in app from sessions
      // Tile 1: Average understanding
      expect(find.text('Average understanding'), findsOneWidget);
      expect(find.text('58 → 76'), findsOneWidget);

      // Tile 2: Caught the trap
      expect(find.text('Caught the trap'), findsOneWidget);
      expect(find.text('3 of 6'), findsWidgets); // tile and/or weak concepts

      // Tile 3: Reached Analyse
      expect(find.text('Reached Analyse'), findsOneWidget);
      expect(find.text('2 of 6'), findsWidgets); // tile and weak concepts

      // 4. Table columns and rows
      expect(find.text('STUDENT'), findsOneWidget);
      expect(find.text('UNDERSTANDING'), findsOneWidget);
      expect(find.text('LEVEL REACHED'), findsOneWidget);
      expect(find.text('TRAP'), findsOneWidget);
      expect(find.text('WEAKEST POINT'), findsOneWidget);

      // Newest non-sample is Alice Nguyen -> labelled "Just finished"
      expect(find.text('Alice Nguyen'), findsOneWidget);
      expect(find.text('Just finished'), findsOneWidget);

      // Trap Caught and Missed texts and icons
      expect(find.text('Caught'), findsWidgets);
      expect(find.text('Missed'), findsWidgets);
      expect(find.byIcon(Icons.shield_rounded), findsWidgets);
      expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);

      // 5. Dark card "Where the class is weakest"
      expect(find.text('Where the class is weakest'), findsOneWidget);
      expect(
        find.text(
          'This shows what each student could explain. What it means is the teacher\'s call.',
        ),
        findsOneWidget,
      );

      // Weak concepts listed with counts
      for (final wc in summary.weakConcepts) {
        expect(find.text(wc.concept), findsWidgets);
        expect(find.text('${wc.count} of ${wc.total}'), findsWidgets);
      }

      // 6. Refresh button
      expect(find.byTooltip('Refresh'), findsOneWidget);

      await cleanup(tester);
    });

    testWidgets('navigates to "/" when Student view is clicked', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestable(size: const Size(1280, 800)));
      await pumpScreen(tester);

      final studentViewBtn = find.text('Student view');
      expect(studentViewBtn, findsOneWidget);

      await tester.tap(studentViewBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Home Student View'), findsOneWidget);

      await cleanup(tester);
    });

    testWidgets('renders cleanly on phone size (390px wide) with horizontal table scroll', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestable(size: const Size(390, 844)));
      await pumpScreen(tester);

      // Header on phone
      expect(find.text('Student view'), findsOneWidget);
      expect(find.text('Sample class data'), findsOneWidget);

      // Title
      expect(find.text(summary.assignment), findsOneWidget);

      // Metrics
      expect(find.text('Average understanding'), findsOneWidget);
      expect(find.text('Caught the trap'), findsOneWidget);
      expect(find.text('Reached Analyse'), findsOneWidget);

      // Table & "Just finished"
      expect(find.text('Just finished'), findsOneWidget);

      // Dark card stacked below
      expect(find.text('Where the class is weakest'), findsOneWidget);
      expect(
        find.text(
          'This shows what each student could explain. What it means is the teacher\'s call.',
        ),
        findsOneWidget,
      );

      // Check horizontal scroll exists
      final hScroll = find.byWidgetPredicate(
        (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      );
      expect(hScroll, findsOneWidget);

      await cleanup(tester);
    });
  });
}
