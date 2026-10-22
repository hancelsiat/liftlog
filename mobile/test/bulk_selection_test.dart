import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:liftlog_mobile/utils/bulk_action.dart';
import 'package:liftlog_mobile/widgets/gym/gym.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: const SizedBox.expand(),
    bottomNavigationBar: SizedBox(width: 360, child: child),
  ),
);

void main() {
  setUpAll(() {
    // Tests have no network; don't try to download fonts.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('runBulk', () {
    test('runs every item in order and keeps going after a failure', () async {
      final seen = <int>[];
      final progress = <String>[];
      final result = await runBulk<int>([1, 2, 3], (i) async {
        seen.add(i);
        if (i == 2) throw Exception('Not found');
      }, onProgress: (done, total) => progress.add('$done/$total'));

      expect(seen, [1, 2, 3]);
      expect(progress, ['1/3', '2/3', '3/3']);
      expect(result.succeeded, 2);
      expect(result.errors, ['Not found']);
      expect(result.total, 3);
    });

    test('message wording', () {
      expect(
        const BulkResult(3, []).message(verb: 'Deleted', noun: 'user'),
        'Deleted 3 users.',
      );
      expect(
        const BulkResult(1, []).message(verb: 'Approved', noun: 'trainer'),
        'Approved 1 trainer.',
      );
      expect(
        const BulkResult(2, [
          'Not found',
        ]).message(verb: 'Removed', noun: 'video'),
        'Removed 2 of 3 videos. 1 failed: Not found',
      );
      expect(
        const BulkResult(0, ['Offline']).message(verb: 'Deleted', noun: 'user'),
        'Deleted 0 of 1 user. Offline',
      );
    });
  });

  group('GymSelectionBar', () {
    testWidgets('select all, clear and close callbacks', (tester) async {
      var selectAll = 0, clear = 0, close = 0;
      Widget bar(int selected) => _host(
        GymSelectionBar(
          selectedCount: selected,
          selectableCount: 3,
          onSelectAll: () => selectAll++,
          onClear: () => clear++,
          onClose: () => close++,
          actions: [GymSmallButton(label: 'Delete', onTap: () {})],
        ),
      );

      await tester.pumpWidget(bar(1));
      expect(find.text('1 OF 3 SELECTED'), findsOneWidget);
      await tester.tap(find.byType(GymCheckbox));
      expect(selectAll, 1);

      await tester.pumpWidget(bar(3));
      await tester.tap(find.byType(GymCheckbox));
      expect(clear, 1);

      await tester.tap(find.byTooltip('Exit selection'));
      expect(close, 1);
    });

    testWidgets('locks every control while busy', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _host(
          GymSelectionBar(
            selectedCount: 2,
            selectableCount: 3,
            busyLabel: 'Deleting 1/2…',
            onSelectAll: () => tapped++,
            onClear: () => tapped++,
            onClose: () => tapped++,
            actions: [GymSmallButton(label: 'Delete', onTap: () => tapped++)],
          ),
        ),
      );

      expect(find.text('DELETING 1/2…'), findsOneWidget);
      await tester.tap(find.byType(GymCheckbox), warnIfMissed: false);
      await tester.tap(find.byTooltip('Exit selection'), warnIfMissed: false);
      await tester.tap(find.text('DELETE'), warnIfMissed: false);
      expect(tapped, 0);
    });

    testWidgets('three actions fit a 360px wide bar', (tester) async {
      await tester.pumpWidget(
        _host(
          GymSelectionBar(
            selectedCount: 12,
            selectableCount: 40,
            onSelectAll: () {},
            onClear: () {},
            onClose: () {},
            actions: [
              GymSmallButton(
                label: 'Reject 12',
                icon: Icons.close,
                onTap: () {},
              ),
              GymSmallButton(
                label: 'Approve 12',
                icon: Icons.check,
                primary: true,
                onTap: () {},
              ),
              GymSmallButton(
                label: 'Delete 12',
                icon: Icons.delete_outline,
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('matchesSearch', () {
    test('empty query matches everything', () {
      expect(matchesSearch('', ['anything']), isTrue);
      expect(matchesSearch('   ', [null]), isTrue);
    });

    test('is case-insensitive and needs every word somewhere', () {
      final fields = ['jdelacruz', 'Juan Dela Cruz', 'juan@gym.ph', null];
      expect(matchesSearch('JUAN', fields), isTrue);
      expect(matchesSearch('cruz gym.ph', fields), isTrue);
      expect(matchesSearch('juan maria', fields), isFalse);
    });
  });

  group('GymSearchField', () {
    testWidgets('reports typing and the clear button resets it', (
      tester,
    ) async {
      final queries = <String>[];
      await tester.pumpWidget(
        _host(GymSearchField(hint: 'Search users', onChanged: queries.add)),
      );
      expect(find.text('Search users'), findsOneWidget);
      expect(find.bySemanticsLabel('Clear search'), findsNothing);

      await tester.enterText(find.byType(TextField), 'ana');
      await tester.pump();
      expect(queries.last, 'ana');

      await tester.tap(find.bySemanticsLabel('Clear search'));
      await tester.pump();
      expect(queries.last, '');
      expect(find.text('ana'), findsNothing);
    });
  });

  group('GymCheckbox', () {
    testWidgets('toggles and is inert when disabled', (tester) async {
      bool? value;
      await tester.pumpWidget(
        _host(GymCheckbox(value: false, onChanged: (v) => value = v)),
      );
      await tester.tap(find.byType(GymCheckbox));
      expect(value, isTrue);

      value = null;
      await tester.pumpWidget(
        _host(const GymCheckbox(value: false, onChanged: null)),
      );
      await tester.tap(find.byType(GymCheckbox));
      expect(value, isNull);
    });
  });
}
