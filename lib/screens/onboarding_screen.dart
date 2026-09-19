import 'package:flutter/material.dart';
import '../theme/app_layout.dart';
import '../widgets/animated_button.dart';

class OnboardingScreen extends StatelessWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppLayout.buttonHorizontalGutter,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'FLD-AYA-01 / CONTINUED EXISTENCE REGISTER\n\nFile once every 39 hours. A local notice is scheduled after 30 hours. If the filing window lapses, the record remains lapsed until you file again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    height: 1.6,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 60),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppLayout.buttonMaxWidth,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: AppLayout.buttonHeight,
                    child: AnimatedButton(
                      onPressed: onComplete,
                      glowColor: Colors.white,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'OPEN REGISTER',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 18,
                            letterSpacing: 2,
                            color: Colors.white,
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
