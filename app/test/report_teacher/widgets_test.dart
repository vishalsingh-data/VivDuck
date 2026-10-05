import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivduck/core/models.dart';
import 'package:vivduck/core/theme.dart';
import 'package:vivduck/report_teacher/widgets/bloom_badge.dart';
import 'package:vivduck/report_teacher/widgets/key_point_tile.dart';
import 'package:vivduck/report_teacher/widgets/score_ring.dart';

Map<String, dynamic> _loadFixture() {
  const contractPath = '../shared/contracts/03_report.json';
  const assetPath = 'assets/fixtures/03_report.json';

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
  final report = Report.fromJson(fixture['response'] as Map<String, dynamic>);

  Widget buildTestable(Widget child) {
    return MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  group('ScoreRing', () {
    testWidgets('pumps with fixture before and after scores and animates', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          ScoreRing(
            before: report.scoreBefore,
            after: report.scoreAfter,
          ),
        ),
      );

      expect(find.byType(ScoreRing), findsOneWidget);

      // On first build (t = 0), center number starts at scoreBefore (54)
      expect(find.text('54'), findsOneWidget);
      expect(find.text('out of 100'), findsOneWidget);

      // Advance through the 1.2s animation
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // After 1.2 seconds, center number counts up to scoreAfter (79)
      expect(find.text('79'), findsOneWidget);
      expect(find.text('out of 100'), findsOneWidget);
    });
  });

  group('KeyPointTile', () {
    testWidgets('pumps solid key point with statement, label, and quote', (tester) async {
      final solidKp = report.keyPoints.firstWhere((k) => k.status == KeyPointStatus.solid);

      await tester.pumpWidget(
        buildTestable(
          KeyPointTile(solidKp),
        ),
      );

      expect(find.byType(KeyPointTile), findsOneWidget);
      expect(find.text(solidKp.statement), findsOneWidget);
      expect(find.text('Solid'), findsOneWidget);
      expect(find.text('You said: "${solidKp.evidenceQuote}"'), findsOneWidget);
    });

    testWidgets('pumps partial key point with statement, label, and quote', (tester) async {
      final partialKp = report.keyPoints.firstWhere((k) => k.status == KeyPointStatus.partial);

      await tester.pumpWidget(
        buildTestable(
          KeyPointTile(partialKp),
        ),
      );

      expect(find.byType(KeyPointTile), findsOneWidget);
      expect(find.text(partialKp.statement), findsOneWidget);
      expect(find.text('Partial'), findsOneWidget);
      expect(find.text('You said: "${partialKp.evidenceQuote}"'), findsOneWidget);
    });

    testWidgets('pumps missing key point showing "Not explained yet"', (tester) async {
      final missingKp = report.keyPoints.firstWhere((k) => k.status == KeyPointStatus.missing);

      await tester.pumpWidget(
        buildTestable(
          KeyPointTile(missingKp),
        ),
      );

      expect(find.byType(KeyPointTile), findsOneWidget);
      expect(find.text(missingKp.statement), findsOneWidget);
      expect(find.text('Missing'), findsOneWidget);
      expect(find.text('Not explained yet'), findsOneWidget);
    });
  });

  group('BloomBadge', () {
    testWidgets('pumps with fixture bloom level "Analyse" and displays all segments', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          BloomBadge(report.bloomReached),
        ),
      );

      expect(find.byType(BloomBadge), findsOneWidget);

      // Level name is displayed
      expect(find.text('Analyse'), findsWidgets);

      // All 3 segment labels are present
      expect(find.text('Understand'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);

      // Under "Analyse", all 3 segments are filled (3 checkmark icons)
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
    });

    testWidgets('pumps with "Apply" level filling 2 segments', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const BloomBadge('Apply'),
        ),
      );

      expect(find.text('Apply'), findsWidgets);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    });

    testWidgets('pumps with "Understand" level filling 1 segment', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const BloomBadge('Understand'),
        ),
      );

      expect(find.text('Understand'), findsWidgets);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(1));
    });
  });
}
