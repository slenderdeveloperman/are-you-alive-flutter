import 'package:flutter/material.dart';
import '../models/badge_models.dart';
import 'cylindrical_badge_chip.dart';

class BadgeDetailSheet extends StatelessWidget {
  const BadgeDetailSheet({super.key, required this.snapshot});

  final BadgeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E0E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'BADGES + OPEN STATS',
                style: TextStyle(
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 10,
                spacing: 12,
                children: [
                  _summaryStat('total', snapshot.appOpenStats.total),
                  _summaryStat('today', snapshot.appOpenStats.today),
                  _summaryStat('week', snapshot.appOpenStats.week),
                  _summaryStat('month', snapshot.appOpenStats.month),
                  _summaryStat('year', snapshot.appOpenStats.year),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  itemCount: snapshot.badges.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final badge = snapshot.badges[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CylindricalBadgeChip(badge: badge),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            badge.definition.description,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.66),
                            ),
                          ),
                        ),
                      ],
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

  Widget _summaryStat(String label, int value) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
