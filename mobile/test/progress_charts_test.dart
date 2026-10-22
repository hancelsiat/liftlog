import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:liftlog_mobile/models/progress.dart';
import 'package:liftlog_mobile/widgets/gym/gym.dart';
import 'package:liftlog_mobile/widgets/progress_charts.dart';

Progress _p(int day, {double? bmi, double? intake, double? deficit}) =>
    Progress(
      id: '$day',
      userId: 'u',
      bmi: bmi,
      caloriesIntake: intake,
      calorieDeficit: deficit,
      date: DateTime(2026, 10, day, 9),
    );

Future<void> _pump(WidgetTester tester, List<Progress> history) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ProgressCharts(history: history),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Color? _tagColor(WidgetTester tester, String label) => tester
    .widget<GymTag>(
      find.ancestor(
        of: find.text(label.toUpperCase()),
        matching: find.byType(GymTag),
      ),
    )
    .color;

void main() {
  setUpAll(() {
    // Tests have no network; don't try to download fonts.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('chartPoints sorts oldest first and skips missing values', () {
    // API returns newest first; one entry has calories only.
    final pts = chartPoints([
      _p(20, bmi: 26),
      _p(15, intake: 2100),
      _p(10, bmi: 27),
    ], (p) => p.bmi);

    expect(pts.map((p) => p.value), [27, 26]);
    expect(pts.first.date.day, 10);
  });

  testWidgets('BMI is a line, intake is bars, deficit is a step line', (
    tester,
  ) async {
    await _pump(tester, [
      _p(3, intake: 2300, deficit: 250),
      _p(2, bmi: 26.4, intake: 2000, deficit: -120),
      _p(1, bmi: 27.1, intake: 2150, deficit: 400),
    ]);

    expect(find.byType(BarChart), findsOneWidget);

    final lines = tester.widgetList<LineChart>(find.byType(LineChart)).toList();
    expect(lines, hasLength(2));
    expect(lines[0].data.lineBarsData.single.isCurved, isTrue);
    expect(lines[1].data.lineBarsData.every((b) => b.isStepLineChart), isTrue);

    // Latest values in the headers. 26.4 is also the BMI low and 2,300 the
    // intake high, so those show twice (header + stat strip).
    expect(find.text('26.4'), findsNWidgets(2));
    expect(find.text('2,300'), findsNWidgets(2));
    expect(find.text('250'), findsOneWidget);
    // Deficit stats: average of 400, -120, 250 and 2 of 3 days in deficit.
    expect(find.text('+177'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('falling BMI above the healthy range is shown as progress', (
    tester,
  ) async {
    await _pump(tester, [_p(2, bmi: 26.4), _p(1, bmi: 27.1)]);

    expect(_tagColor(tester, '\u22120.7'), AuthColors.accent);
    expect(_tagColor(tester, 'Over'), GymColors.warn);
  });

  testWidgets('a surplus is tagged and coloured as danger', (tester) async {
    await _pump(tester, [_p(2, deficit: -150), _p(1, deficit: 300)]);

    expect(_tagColor(tester, 'Surplus'), AuthColors.danger);
    expect(_tagColor(tester, '\u2212450'), AuthColors.danger);
    expect(find.text('1/2'), findsOneWidget); // days in deficit
  });

  testWidgets('a single entry plots without a change tag', (tester) async {
    await _pump(tester, [_p(1, bmi: 22, intake: 1800, deficit: 0)]);

    expect(tester.takeException(), isNull);
    expect(find.byType(BarChart), findsOneWidget);
    expect(find.byIcon(Icons.north_east), findsNothing);
    expect(find.byIcon(Icons.south_east), findsNothing);
  });

  testWidgets('a metric with no entries shows the empty plot', (tester) async {
    await _pump(tester, [_p(1, bmi: 24)]);

    expect(find.text('NOTHING TO PLOT YET'), findsNWidgets(2));
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
  });
}
