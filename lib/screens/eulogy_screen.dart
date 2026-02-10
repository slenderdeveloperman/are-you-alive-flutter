import 'package:flutter/material.dart';
import '../theme/app_layout.dart';
import '../widgets/animated_button.dart';

class EulogyScreen extends StatelessWidget {
  final String userName;
  final int deathStreakCount;
  final VoidCallback onRiseAgain;

  const EulogyScreen({
    super.key,
    required this.userName,
    required this.deathStreakCount,
    required this.onRiseAgain,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[850],
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppLayout.buttonHorizontalGutter,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // R.I.P. header
                Text(
                  'R.I.P.',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 30),

                // User name in red
                Text(
                  userName,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 24,
                    color: Colors.red.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 40),

                // Survival message
                Text(
                  'They survived $deathStreakCount ${deathStreakCount == 1 ? 'day' : 'days'}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'They will be remembered.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 60),

                // Rise again button with scale + glow animation
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppLayout.buttonMaxWidth,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: AppLayout.buttonHeight,
                    child: AnimatedButton(
                      onPressed: onRiseAgain,
                      glowColor: Colors.red,
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
                          'Rise again',
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
