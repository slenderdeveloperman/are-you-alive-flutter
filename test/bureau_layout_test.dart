import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:are_you_alive_flutter/widgets/filing_block.dart';

void main() {
  for (final width in <double>[320, 360, 390, 430]) {
    testWidgets('FilingBlock fits at \${width.toInt()} logical px', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: FilingBlock(
                  status: 'ACTION REQUIRED',
                  fields: <FilingField>[
                    FilingField('INTERVAL', '39 HOURS'),
                    FilingField('WITNESS', 'DESIGNATED / PENDING'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('filing-block')), findsOneWidget);
      expect(tester.takeException(), isNull);

      final blockSize = tester.getSize(find.byKey(const ValueKey('filing-block')));
      expect(blockSize.width, lessThanOrEqualTo(width - 32));
    });
  }
}