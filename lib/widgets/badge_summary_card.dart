import 'package:flutter/material.dart';
import '../models/badge_models.dart';
import 'cylindrical_badge_chip.dart';

class BadgeSummaryCard extends StatelessWidget {
  const BadgeSummaryCard({super.key, required this.snapshot});

  final BadgeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final earnedCount = snapshot.badges.where((badge) => badge.earned).length;
    final nextTarget = snapshot.badges.firstWhere(
      (badge) => !badge.earned,
      orElse: () => snapshot.topBadge,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'BADGE SUMMARY',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  letterSpacing: 1.6,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$earnedCount/${snapshot.badges.length} unlocked',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CylindricalBadgeChip(badge: snapshot.topBadge, compact: true),
          const SizedBox(height: 8),
          Text(
            'opens today ${snapshot.appOpenStats.today}  week ${snapshot.appOpenStats.week}  month ${snapshot.appOpenStats.month}  year ${snapshot.appOpenStats.year}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'next target this week: ${nextTarget.definition.title} - ${nextTarget.hint}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
