import 'package:flutter/material.dart';
import '../models/badge_models.dart';
import '../widgets/cylindrical_badge_chip.dart';

class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key, required this.snapshot});

  final BadgeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final unlockedCount = snapshot.badges.where((badge) => badge.earned).length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'badges',
          style: TextStyle(
            fontFamily: 'monospace',
            letterSpacing: 2,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$unlockedCount/${snapshot.badges.length} unlocked',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  itemCount: snapshot.badges.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final badge = snapshot.badges[index];
                    return Container(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CylindricalBadgeChip(badge: badge),
                          const SizedBox(height: 8),
                          Text(
                            badge.definition.description,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.8),
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            badge.earned
                                ? 'unlocked'
                                : 'progress ${badge.current}/${badge.target} - ${badge.hint.toLowerCase()}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10.5,
                              color: Colors.white.withValues(alpha: 0.64),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
