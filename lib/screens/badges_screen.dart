import 'package:flutter/material.dart';
import '../models/badge_models.dart';
import '../widgets/cylindrical_badge_chip.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key, required this.snapshot});

  final BadgeSnapshot snapshot;

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  BadgeId? _expandedBadgeId;

  @override
  Widget build(BuildContext context) {
    final unlockedCount =
        widget.snapshot.badges.where((badge) => badge.earned).length;

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
                '$unlockedCount/${widget.snapshot.badges.length} unlocked',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: widget.snapshot.badges.length,
                  itemBuilder: (context, index) {
                    final badge = widget.snapshot.badges[index];
                    return _BadgeGridItem(
                      badge: badge,
                      isExpanded: _expandedBadgeId == badge.definition.id,
                      onTap: () => _toggleExpanded(badge),
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

  void _toggleExpanded(BadgeProgress badge) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _BadgeDetailSheet(badge: badge),
    );
  }
}

class _BadgeGridItem extends StatelessWidget {
  const _BadgeGridItem({
    required this.badge,
    required this.isExpanded,
    required this.onTap,
  });

  final BadgeProgress badge;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: CylindricalBadgeChip(
          badge: badge,
          iconOnly: true,
        ),
      ),
    );
  }
}

class _BadgeDetailSheet extends StatelessWidget {
  const _BadgeDetailSheet({required this.badge});

  final BadgeProgress badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          CylindricalBadgeChip(badge: badge),
          const SizedBox(height: 16),
          Text(
            badge.definition.description,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  badge.earned ? Icons.check_circle : Icons.hourglass_empty,
                  size: 16,
                  color: badge.earned
                      ? const Color(0xFF3FAE7A)
                      : Colors.white.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Text(
                  badge.earned
                      ? 'unlocked'
                      : '${badge.current}/${badge.target} - ${badge.hint.toLowerCase()}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: badge.earned
                        ? const Color(0xFF3FAE7A)
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
