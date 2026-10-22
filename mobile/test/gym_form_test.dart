import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:liftlog_mobile/widgets/gym/gym.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  setUpAll(() {
    // Tests have no network; don't try to download fonts.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('GymRadioList', () {
    testWidgets('reports the tapped option', (tester) async {
      String? picked;
      await tester.pumpWidget(
        _host(
          GymRadioList<String>(
            options: const ['A', 'B', 'C'],
            selected: 'A',
            onChanged: (v) => picked = v,
          ),
        ),
      );

      await tester.tap(find.text('B'));
      expect(picked, 'B');
    });

    testWidgets('rows have no tap handler when disabled', (tester) async {
      await tester.pumpWidget(
        _host(
          const GymRadioList<String>(
            options: ['A', 'B'],
            selected: 'A',
            onChanged: null,
          ),
        ),
      );

      final row = tester.widget<GestureDetector>(
        find
            .ancestor(
              of: find.text('B'),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      expect(row.onTap, isNull);
    });
  });

  group('GymChoiceChip', () {
    testWidgets('shows an uppercase label and calls onTap', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          GymChoiceChip(
            label: 'strength',
            selected: false,
            onTap: () => taps++,
          ),
        ),
      );

      expect(find.text('STRENGTH'), findsOneWidget);
      await tester.tap(find.text('STRENGTH'));
      expect(taps, 1);
    });
  });

  group('GymFormDialog', () {
    testWidgets('Cancel pops the dialog with no result', (tester) async {
      String? result = 'unset';
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    result = await showGymDialog<String>(
                      context: context,
                      builder: (ctx) => GymFormDialog(
                        title: 'Remove Video',
                        confirmLabel: 'Remove',
                        onConfirm: () => Navigator.pop(ctx, 'ok'),
                        child: const Text('Body'),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Remove Video'), findsOneWidget);

      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(find.text('Remove Video'), findsNothing);
      expect(result, isNull);
    });

    testWidgets('confirm returns the value; disabled confirm does nothing', (
      tester,
    ) async {
      String? result;
      var enabled = false;
      late StateSetter rebuild;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    result = await showGymDialog<String>(
                      context: context,
                      builder: (ctx) => StatefulBuilder(
                        builder: (ctx, setState) {
                          rebuild = setState;
                          return GymFormDialog(
                            title: 'Reject Trainer',
                            confirmLabel: 'Reject',
                            onConfirm: enabled
                                ? () => Navigator.pop(ctx, 'reason')
                                : null,
                            child: const Text('Body'),
                          );
                        },
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Disabled: tapping does not close the dialog.
      await tester.tap(find.text('REJECT'));
      await tester.pumpAndSettle();
      expect(find.text('Reject Trainer'), findsOneWidget);

      rebuild(() => enabled = true);
      await tester.pump();
      await tester.tap(find.text('REJECT'));
      await tester.pumpAndSettle();

      expect(find.text('Reject Trainer'), findsNothing);
      expect(result, 'reason');
    });
  });
}
