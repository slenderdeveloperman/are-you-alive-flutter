import 'package:flutter/material.dart';
import '../models/badge_models.dart';
import '../widgets/animated_button.dart';
import '../widgets/cylindrical_badge_chip.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({
    super.key,
    required this.snapshot,
    DateTime Function()? nowProvider,
  }) : _nowProvider = nowProvider;

  final BadgeSnapshot snapshot;
  final DateTime Function()? _nowProvider;

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  BadgeId? _expandedBadgeId;

  static const _recentUnlockThreshold = Duration(minutes: 10);

  DateTime _now() => widget._nowProvider?.call() ?? DateTime.now();

  bool _isRecentlyUnlocked(BadgeProgress badge) {
    final earnedAtMs = badge.earnedAtMs;
    if (!badge.earned || earnedAtMs == null) return false;
    final earnedAt = DateTime.fromMillisecondsSinceEpoch(earnedAtMs);
    return _now().difference(earnedAt) <= _recentUnlockThreshold;
  }

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
                      celebrateUnlock: _isRecentlyUnlocked(badge),
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

class _BadgeGridItem extends StatefulWidget {
  const _BadgeGridItem({
    required this.badge,
    required this.isExpanded,
    required this.onTap,
    required this.celebrateUnlock,
  });

  final BadgeProgress badge;
  final bool isExpanded;
  final VoidCallback onTap;
  final bool celebrateUnlock;

  @override
  State<_BadgeGridItem> createState() => _BadgeGridItemState();
}

class _BadgeGridItemState extends State<_BadgeGridItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _glowOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    // Overshoot slightly past 1.0 then settle — celebratory, not just a
    // plain fade-in. elasticOut is too bouncy for a 56px chip; easeOutBack
    // gives a subtle single overshoot.
    _scale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _glowOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    if (widget.celebrateUnlock) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedButton(
      onPressed: widget.onTap,
      enableGlow: false,
      pressedScale: 0.93,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              key: ValueKey('badge-scale-${widget.badge.definition.id.name}'),
              scale: _scale.value,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: widget.celebrateUnlock
                      ? [
                          BoxShadow(
                            color: const Color(0xFF3FAE7A)
                                .withValues(alpha: 0.5 * _glowOpacity.value),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ]
                      : const [],
                ),
                child: child,
              ),
            );
          },
          child: CylindricalBadgeChip(
            key: ValueKey('badge-chip-${widget.badge.definition.id.name}'),
            badge: widget.badge,
            iconOnly: true,
          ),
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
