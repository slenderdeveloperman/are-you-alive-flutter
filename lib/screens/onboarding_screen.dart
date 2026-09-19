import 'package:flutter/material.dart';

import '../theme/app_layout.dart';
import '../theme/bureau_tokens.dart';
import '../widgets/animated_button.dart';
import '../widgets/filing_block.dart';

class OnboardingScreen extends StatelessWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BureauTokens.ink,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppLayout.buttonHorizontalGutter,
              vertical: 32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const FilingBlock(
                  status: 'UNFILED',
                  fields: [
                    FilingField('CLASS', 'CONTINUED EXISTENCE'),
                    FilingField('INTERVAL', '39 HOURS'),
                    FilingField('NOTICE', 'LOCAL / 30H'),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'Continued Existence Register',
                  style: BureauTokens.displayTitle.copyWith(
                    color: BureauTokens.paper,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'File once every 39 hours. A local notice is scheduled after 30 hours. If the filing window lapses, the record stays lapsed until you file again.',
                  style: BureauTokens.filingValue.copyWith(
                    color: BureauTokens.mutedOnInk,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 40),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppLayout.buttonMaxWidth,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: AppLayout.buttonHeight,
                    child: AnimatedButton(
                      onPressed: onComplete,
                      enableGlow: false,
                      pressedScale: 0.98,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: BureauTokens.paper,
                          border: Border.all(color: BureauTokens.paper),
                        ),
                        child: Text(
                          'OPEN REGISTER',
                          style: BureauTokens.filingLabel.copyWith(
                            color: BureauTokens.ink,
                            fontSize: 13,
                            letterSpacing: 2.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
