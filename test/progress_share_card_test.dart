import 'package:are_you_alive_flutter/models/share_models.dart';
import 'package:are_you_alive_flutter/widgets/progress_share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('extract includes the shared filing stamp and fits long lines', (
    tester,
  ) async {
    const preset = SharePreset(
      id: 'test-extract',
      title: 'Test Extract',
      description: 'Test extract',
      theme: ShareTheme.nearMiss,
      thumbnailAssetPath: '',
      backgroundAssetPath: '',
      imageTemplates: <String>[],
      captionTemplate: 'Test',
      defaultFields: <ShareField>{},
      optionalFields: <ShareField>{},
      privacyLevel: SharePrivacyLevel.low,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          child: ProgressShareCard(
            content: ShareContent(
              preset: preset,
              imageLines: <String>[
                'A deliberately long register line that must fit the extract width',
              ],
              caption: 'Test',
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('filing-stamp')), findsOneWidget);
    expect(find.textContaining('…'), findsOneWidget);
  });
}
