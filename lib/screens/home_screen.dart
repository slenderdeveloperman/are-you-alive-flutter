import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'badges_screen.dart';
import '../widgets/heart_painter.dart';
import '../widgets/animated_button.dart';
import '../widgets/bottom_action_pill.dart';
import '../widgets/typewriter_text.dart';
import '../widgets/are_you_alive_loop.dart';
import '../widgets/glitch_text.dart';
import '../widgets/heart_particles.dart';
import '../models/badge_models.dart';
import '../repositories/timer_message_repository.dart';
import '../services/badge_service.dart';
import '../services/notification_service.dart';
import '../theme/app_layout.dart';
import '../theme/motion_tokens.dart';
import '../models/share_models.dart';
import '../utils/date_utils.dart';
import '../widgets/share_preset_sheet.dart';

enum _HeartbeatPhase { inactive, normal, erratic, expired }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, DateTime Function()? nowProvider, Random? random})
    : _nowProvider = nowProvider,
      _random = random;

  final DateTime Function()? _nowProvider;
  final Random? _random;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static final Uri _builtByUri = Uri.parse('https://x.com/slndrtweeterman');
  String _userName = '';
  bool _hasCheckedIn = false;
  int _streakCount = 0;
  int _previousStreak = 0; // For streak count-up animation
  bool _streakJustChanged = false; // For scale pop animation
  int _checkInsSinceDeath = 3; // Start at 3 (fully healed) for new users
  bool _isCheckingIn = false; // For heart particle burst

  late AnimationController _heartbeatController;
  late Animation<double> _heartbeatAnimation;
  _HeartbeatPhase _heartbeatPhase = _HeartbeatPhase.inactive;
  Timer? _erraticBeatTimer;
  late final Random _random;
  double _erraticScaleMultiplier = 1.0;
  Duration? _pendingBeatDuration;
  double? _pendingScaleMultiplier;

  // Shake animation for check-in
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // Countdown timer state
  Timer? _countdownTimer;
  Duration _remainingTime = const Duration(hours: 39);
  int? _notificationTimestamp;
  String _activeDayKey = '';

  // Decay level for heart visual (0.0 = healthy, 1.0 = dead)
  double _decayLevel = 0.0;
  BadgeSnapshot? _badgeSnapshot;
  String _timerMessage = '';
  String? _lastTimerMessageDate;

  static const Duration _normalHeartbeatDuration = Duration(milliseconds: 600);
  static const Duration _erraticWindowStart = Duration(hours: 24);
  static const Duration _expiryThreshold = Duration(hours: 39);

  @override
  void initState() {
    super.initState();
    _random = widget._random ?? Random();
    _activeDayKey = dateOnly(_now());
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
    _setupAnimation();
    _resetTimerAndCountdown();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if user has already checked in today
    final hasCheckedInToday = await _hasCheckedInToday();

    final loadedStreak = prefs.getInt('streakCount') ?? 0;
    setState(() {
      _userName = prefs.getString('userName') ?? 'human';
      _previousStreak = loadedStreak; // Set both to same value on initial load
      _streakCount = loadedStreak;
      _checkInsSinceDeath = prefs.getInt('checkInsSinceDeath') ?? 3;
      _hasCheckedIn = hasCheckedInToday; // Set based on calendar day
      _activeDayKey = dateOnly(_now());
    });
    await _refreshBadgeSnapshot();
    await _refreshDailyTimerMessage(force: true);
  }

  /// Determines if the user has already checked in today
  Future<bool> _hasCheckedInToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = dateOnly(_now());
    final lastCheckInDate = prefs.getString('lastCheckInDate');

    return lastCheckInDate == today;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      // Check if user has already checked in today
      final hasCheckedInToday = await _hasCheckedInToday();

      setState(() {
        _hasCheckedIn = hasCheckedInToday; // Set based on calendar day
      });

      // Reset timer when app comes back to foreground
      await _resetTimerAndCountdown();

      // Reload user data (streak might have changed)
      await _loadUserData();
      await _refreshDailyTimerMessage(force: true);
    }
  }

  /// Check if auto-reset is needed, schedule notification, then initialize countdown
  Future<void> _resetTimerAndCountdown() async {
    final prefs = await SharedPreferences.getInstance();
    final lastActiveTimestamp = prefs.getInt('lastActiveTimestamp');

    if (lastActiveTimestamp != null) {
      final elapsed = _now().millisecondsSinceEpoch - lastActiveTimestamp;
      final autoResetThreshold = const Duration(
        hours: 41,
      ).inMilliseconds; // 39h timer + 2h grace

      if (elapsed >= autoResetThreshold) {
        // Auto-reset: more than 41 hours have passed since last check-in
        // Schedule a fresh notification (this also updates lastActiveTimestamp)
        await _scheduleNotification();
      }
    }

    await _initCountdown();
  }

  void _setupAnimation() {
    // Heartbeat animation - continuous scale pulsing
    _heartbeatController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _heartbeatAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _heartbeatController, curve: Curves.easeInOut),
    );

    _heartbeatController.addStatusListener(_onHeartbeatStatusChanged);

    // Shake animation - rapid horizontal vibration
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _shakeAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
          TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
          TweenSequenceItem(tween: Tween(begin: 10.0, end: 0.0), weight: 1),
        ]).animate(
          CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut),
        );
    _applyHeartbeatPhase(_HeartbeatPhase.inactive);
  }

  /// Calculate decay level based on elapsed time since last check-in
  double _calculateDecayLevel() {
    if (_notificationTimestamp == null) return 0.0;

    // Calculate time-based decay
    final totalDuration = const Duration(hours: 39).inMilliseconds;
    final lastActiveTimestamp = _notificationTimestamp! - totalDuration;
    final elapsed = _now().millisecondsSinceEpoch - lastActiveTimestamp;
    final timeDecay = (elapsed / totalDuration).clamp(0.0, 1.0);

    // Apply healing penalty if recovering from death
    // checkInsSinceDeath: 0 = just died, 1 = 1 day healed, 2 = 2 days, 3+ = fully healed
    final healingFactor = (_checkInsSinceDeath / 3.0).clamp(0.0, 1.0);
    final healingPenalty =
        1.0 - healingFactor; // 1.0 = max penalty, 0.0 = no penalty

    // Combine: max of time decay and healing penalty
    // This ensures heart shows damage from either time OR recent death
    return (timeDecay > healingPenalty ? timeDecay : healingPenalty * 0.75)
        .clamp(0.0, 1.0);
  }

  /// Increment streak if this is the first check-in of the day
  Future<void> _incrementStreakIfNewDay() async {
    final prefs = await SharedPreferences.getInstance();
    final today = dateOnly(_now());
    final lastCheckInDate = prefs.getString('lastCheckInDate');

    if (lastCheckInDate != today) {
      final currentStreak = prefs.getInt('streakCount') ?? 0;
      await prefs.setInt('streakCount', currentStreak + 1);
      await prefs.setString('lastCheckInDate', today);

      // Increment healing counter (caps at 3)
      final currentHealing = prefs.getInt('checkInsSinceDeath') ?? 3;
      if (currentHealing < 3) {
        await prefs.setInt('checkInsSinceDeath', currentHealing + 1);
      }

      setState(() {
        _previousStreak = currentStreak; // Old value for count-up animation
        _streakCount = currentStreak + 1;
        _streakJustChanged = true; // Trigger scale pop
        _checkInsSinceDeath = (currentHealing + 1).clamp(0, 3);
      });

      // Reset scale pop flag after animation completes
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _streakJustChanged = false;
            _previousStreak = _streakCount; // Sync for next animation
          });
        }
      });
    }
  }

  Future<void> _onCheckIn() async {
    setState(() {
      _hasCheckedIn = true;
      _isCheckingIn = true; // Trigger particle burst
      _activeDayKey = dateOnly(_now());
    });
    _applyHeartbeatPhase(_HeartbeatPhase.normal);

    // Reset particle trigger after burst completes
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _isCheckingIn = false;
        });
      }
    });

    // Start shake animation, then transition to heartbeat.
    // Reduced motion: skip the positional shake — the glow pulse and color
    // change already communicate the check-in.
    if (!MotionTokens.reducedMotion) {
      _shakeController.forward().then((_) {
        _shakeController.reset();
      });
    }

    // Save check-in metadata for badge logic before resetting the timer.
    await BadgeService().recordCheckInEvent(
      now: _now(),
      remaining: _remainingTime,
    );

    // Increment streak if new day
    await _incrementStreakIfNewDay();

    // Always schedule a fresh notification on button click (resets timer to 39:00:00)
    await _scheduleNotification();
    await _initCountdown();
    await _refreshBadgeSnapshot();
    await _refreshDailyTimerMessage(force: true);
  }

  Future<void> _scheduleNotification() async {
    await NotificationService().scheduleInactivityNotification();
  }

  Future<void> _initCountdown() async {
    // Cancel any existing timer first
    _countdownTimer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    final lastActiveTimestamp = prefs.getInt('lastActiveTimestamp');
    if (lastActiveTimestamp != null) {
      // Notification is scheduled for 39 hours after lastActiveTimestamp
      _notificationTimestamp =
          lastActiveTimestamp + const Duration(hours: 39).inMilliseconds;
    }
    _reconcileHeartbeatPhase(lastActiveTimestamp: lastActiveTimestamp);
    _calculateRemainingTime();
    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _calculateRemainingTime();
    });
  }

  void _calculateRemainingTime() {
    final now = _now();
    final today = dateOnly(now);
    final dayChanged = today != _activeDayKey;
    if (dayChanged) {
      _activeDayKey = today;
    }

    if (_notificationTimestamp == null) {
      setState(() {
        _remainingTime = const Duration(hours: 39);
        _decayLevel = 0.0;
        if (dayChanged && _hasCheckedIn) {
          _hasCheckedIn = false;
        }
      });
      _reconcileHeartbeatPhase(lastActiveTimestamp: null);
      return;
    }

    final scheduledTime = DateTime.fromMillisecondsSinceEpoch(
      _notificationTimestamp!,
    );
    final remaining = scheduledTime.difference(now);
    final lastActiveTimestamp =
        _notificationTimestamp! - _expiryThreshold.inMilliseconds;
    final isExpired = !remaining.isNegative ? remaining == Duration.zero : true;

    setState(() {
      _remainingTime = remaining.isNegative ? Duration.zero : remaining;
      _decayLevel = _calculateDecayLevel();
      if (dayChanged && _hasCheckedIn) {
        _hasCheckedIn = false;
      }
    });

    if (_hasCheckedIn && _lastTimerMessageDate != today) {
      unawaited(_refreshDailyTimerMessage());
    }

    if (isExpired) {
      _applyHeartbeatPhase(_HeartbeatPhase.expired);
    } else {
      _reconcileHeartbeatPhase(
        lastActiveTimestamp: lastActiveTimestamp,
        now: now,
      );
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _fallbackTimerMessage() {
    final safeName = _userName.trim().isEmpty ? 'human' : _userName.trim();
    return 'check in before ${_formatDuration(_remainingTime)}, $safeName';
  }

  List<_MessageRange> _findRangesIgnoringCase(String source, String token) {
    final trimmedToken = token.trim();
    if (trimmedToken.isEmpty) return const [];

    final lowerSource = source.toLowerCase();
    final lowerToken = trimmedToken.toLowerCase();
    final matches = <_MessageRange>[];
    var searchFrom = 0;

    while (searchFrom < source.length) {
      final index = lowerSource.indexOf(lowerToken, searchFrom);
      if (index == -1) break;
      matches.add(
        _MessageRange(start: index, end: index + trimmedToken.length),
      );
      searchFrom = index + trimmedToken.length;
    }

    return matches;
  }

  TextSpan _buildTimerMessageSpan(String message) {
    const baseStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 17,
      height: 1.5,
      color: Colors.white,
    );
    final highlightStyle = baseStyle.copyWith(
      color: Colors.red.withValues(alpha: 0.9),
    );

    final currentCountdown = _formatDuration(_remainingTime);
    final resolvedMessage = message.replaceAll(
      RegExp(r'\b\d{2}:\d{2}:\d{2}\b'),
      currentCountdown,
    );
    final safeName = _userName.trim().isEmpty ? 'human' : _userName.trim();
    final ranges = <_MessageRange>[
      ..._findRangesIgnoringCase(resolvedMessage, safeName),
      ..._findRangesIgnoringCase(resolvedMessage, currentCountdown),
    ];

    if (ranges.isEmpty) {
      return TextSpan(text: resolvedMessage, style: baseStyle);
    }

    ranges.sort((a, b) => a.start.compareTo(b.start));
    final merged = <_MessageRange>[];
    for (final range in ranges) {
      if (merged.isEmpty || range.start > merged.last.end) {
        merged.add(range);
      } else {
        merged[merged.length - 1] = _MessageRange(
          start: merged.last.start,
          end: max(merged.last.end, range.end),
        );
      }
    }

    final children = <TextSpan>[];
    var cursor = 0;
    for (final range in merged) {
      if (cursor < range.start) {
        children.add(
          TextSpan(
            text: resolvedMessage.substring(cursor, range.start),
            style: baseStyle,
          ),
        );
      }
      children.add(
        TextSpan(
          text: resolvedMessage.substring(range.start, range.end),
          style: highlightStyle,
        ),
      );
      cursor = range.end;
    }

    if (cursor < resolvedMessage.length) {
      children.add(
        TextSpan(text: resolvedMessage.substring(cursor), style: baseStyle),
      );
    }

    return TextSpan(style: baseStyle, children: children);
  }

  Future<void> _refreshDailyTimerMessage({bool force = false}) async {
    final now = _now();
    final today = dateOnly(now);
    if (!force && _lastTimerMessageDate == today && _timerMessage.isNotEmpty) {
      return;
    }

    String message;
    try {
      message = await TimerMessageRepository().getDailyMessage(
        userName: _userName,
        countdownText: _formatDuration(_remainingTime),
        now: now,
      );
    } catch (_) {
      message = _fallbackTimerMessage();
    }

    if (!mounted) return;
    setState(() {
      _timerMessage = message;
      _lastTimerMessageDate = today;
    });
  }

  Future<void> _refreshBadgeSnapshot() async {
    final snapshot = await BadgeService().evaluate(now: _now());
    if (!mounted) return;
    setState(() {
      _badgeSnapshot = snapshot;
    });
  }

  void _openBadgesScreen() {
    final snapshot = _badgeSnapshot;
    if (snapshot == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BadgesScreen(
          snapshot: snapshot,
          nowProvider: widget._nowProvider,
        ),
      ),
    );
  }

  Future<void> _openShareSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SharePresetSheet(
        input: SharePayloadInput(
          streakDays: _streakCount,
          remaining: _remainingTime,
          timerMessage: _timerMessage.isNotEmpty
              ? _timerMessage
              : _fallbackTimerMessage(),
          userName: _userName,
          now: _now(),
          badgeSnapshot: _badgeSnapshot,
          notificationTimestampMs: _notificationTimestamp,
        ),
      ),
    );
  }

  Future<void> _openBuiltByProfile() async {
    final didLaunch = await launchUrl(
      _builtByUri,
      mode: LaunchMode.externalApplication,
    );
    if (!didLaunch && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open profile.')));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _erraticBeatTimer?.cancel();
    _heartbeatController.dispose();
    _shakeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  _HeartbeatPhase _computeHeartbeatPhase({
    required int? lastActiveTimestamp,
    required DateTime now,
  }) {
    if (lastActiveTimestamp == null) {
      return _HeartbeatPhase.inactive;
    }

    final elapsed = now.millisecondsSinceEpoch - lastActiveTimestamp;

    if (elapsed >= _expiryThreshold.inMilliseconds) {
      return _HeartbeatPhase.expired;
    }

    if (elapsed >= _erraticWindowStart.inMilliseconds) {
      return _HeartbeatPhase.erratic;
    }

    return _HeartbeatPhase.normal;
  }

  void _reconcileHeartbeatPhase({
    required int? lastActiveTimestamp,
    DateTime? now,
  }) {
    final nextPhase = _computeHeartbeatPhase(
      lastActiveTimestamp: lastActiveTimestamp,
      now: now ?? _now(),
    );
    _applyHeartbeatPhase(nextPhase);
  }

  DateTime _now() {
    return widget._nowProvider?.call() ?? DateTime.now();
  }

  void _applyHeartbeatPhase(_HeartbeatPhase phase) {
    if (_heartbeatPhase == phase) {
      if (phase == _HeartbeatPhase.erratic &&
          (_erraticBeatTimer == null || !_heartbeatController.isAnimating)) {
        _startErraticHeartbeat();
      }
      return;
    }

    if (_heartbeatPhase != _HeartbeatPhase.erratic) {
      _erraticBeatTimer?.cancel();
      _erraticBeatTimer = null;
    }

    _heartbeatPhase = phase;

    switch (phase) {
      case _HeartbeatPhase.inactive:
      case _HeartbeatPhase.expired:
        _erraticBeatTimer?.cancel();
        _erraticBeatTimer = null;
        _erraticScaleMultiplier = 1.0;
        _heartbeatController.stop();
        _heartbeatController.reset();
        break;
      case _HeartbeatPhase.normal:
        _erraticBeatTimer?.cancel();
        _erraticBeatTimer = null;
        _erraticScaleMultiplier = 1.0;
        _heartbeatController.duration = _normalHeartbeatDuration;
        _heartbeatController.stop();
        _heartbeatController.repeat(reverse: true);
        break;
      case _HeartbeatPhase.erratic:
        _startErraticHeartbeat();
        break;
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _onHeartbeatStatusChanged(AnimationStatus status) {
    if (_heartbeatPhase != _HeartbeatPhase.erratic) return;
    if (status != AnimationStatus.dismissed &&
        status != AnimationStatus.completed) {
      return;
    }
    if (_pendingBeatDuration == null) return;

    // We're at a clean boundary (value is exactly 0.0 or 1.0) — safe to
    // change duration and restart the repeat cycle with no direction jump.
    _heartbeatController.duration = _pendingBeatDuration;
    _erraticScaleMultiplier = _pendingScaleMultiplier!;
    _pendingBeatDuration = null;
    _pendingScaleMultiplier = null;

    _heartbeatController.stop();
    _heartbeatController.repeat(reverse: true);
  }

  void _startErraticHeartbeat() {
    _erraticBeatTimer?.cancel();
    _applyErraticBeatProfile(immediate: true);
  }

  void _applyErraticBeatProfile({bool immediate = false}) {
    if (!mounted || _heartbeatPhase != _HeartbeatPhase.erratic) {
      return;
    }

    final beatDuration = Duration(
      milliseconds: 350 + _random.nextInt(550), // 350-899ms
    );
    final reducedMotion = MotionTokens.reducedMotion;
    // Reduced motion: keep the erratic *timing* (still communicates urgency)
    // but dampen the extra scale swing to a barely-there range.
    final scaleMultiplier = reducedMotion
        ? 0.98 + (_random.nextDouble() * 0.02) // 0.98-1.00
        : 0.92 + (_random.nextDouble() * 0.10); // 0.92-1.02

    if (immediate) {
      _heartbeatController.duration = beatDuration;
      _erraticScaleMultiplier = scaleMultiplier;
      _heartbeatController.stop();
      _heartbeatController.repeat(reverse: true);
    } else {
      _pendingBeatDuration = beatDuration;
      _pendingScaleMultiplier = scaleMultiplier;
    }

    final nextChangeDelay = Duration(
      milliseconds: 250 + _random.nextInt(900), // 250-1149ms
    );
    _erraticBeatTimer = Timer(nextChangeDelay, _applyErraticBeatProfile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Heart and button/message positioned higher on screen
                Expanded(
                  child: Align(
                    alignment: const Alignment(0, -0.55),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: Listenable.merge([
                            _heartbeatAnimation,
                            _shakeAnimation,
                          ]),
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(_shakeAnimation.value, 6),
                              child: Transform.scale(
                                key: const ValueKey('heartbeat-scale'),
                                scale:
                                    (_heartbeatAnimation.value *
                                            (_heartbeatPhase ==
                                                    _HeartbeatPhase.erratic
                                                ? _erraticScaleMultiplier
                                                : 1.0))
                                        .clamp(0.8, 1.05),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CustomPaint(
                                      size: const Size(150, 150),
                                      painter: HeartPainter(
                                        fillAmount: 1.0,
                                        isActive: _hasCheckedIn,
                                        decayLevel: _decayLevel,
                                      ),
                                    ),
                                    // Particle overlay
                                    HeartParticles(
                                      heartSize: const Size(150, 150),
                                      isCheckingIn: _isCheckingIn,
                                      decayLevel: _decayLevel,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        TweenAnimationBuilder<int>(
                          tween: IntTween(begin: _previousStreak, end: _streakCount),
                          duration: MotionTokens.celebrationDuration,
                          curve: MotionTokens.easeOutStrong,
                          builder: (context, value, child) {
                            return TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 1.0,
                                end: _streakJustChanged ? 1.15 : 1.0,
                              ),
                              duration: MotionTokens.selectionDuration,
                              curve: MotionTokens.easeOut,
                              builder: (context, scale, _) {
                                return Transform.scale(
                                  scale: scale,
                                  child: Text(
                                    '$value ${value == 1 ? 'day' : 'days'} alive',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 14,
                                      color: Colors.white.withValues(alpha: 0.74),
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 20),

                        // Show button with fade+slide animation
                        AnimatedSwitcher(
                          duration: MotionTokens.entranceDuration,
                          transitionBuilder: (child, animation) {
                            final slideAnimation =
                                Tween<Offset>(
                                  begin: const Offset(0, 0.1),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: animation,
                                    curve: MotionTokens.easeOut,
                                  ),
                                );
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: slideAnimation,
                                child: child,
                              ),
                            );
                          },
                          child: !_hasCheckedIn
                              ? Padding(
                                  key: const ValueKey('check-in-button'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal:
                                        AppLayout.buttonHorizontalGutter,
                                  ),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: AppLayout.buttonMaxWidth,
                                    ),
                                    child: SizedBox(
                                      width: double.infinity,
                                      height: AppLayout.buttonHeight,
                                      child: AnimatedButton(
                                        onPressed: _onCheckIn,
                                        glowColor: Colors.red,
                                        child: Container(
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.3,
                                              ),
                                            ),
                                          ),
                                          child: const Text(
                                            "Yes, I'm alive",
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
                                )
                              : const SizedBox.shrink(key: ValueKey('empty')),
                        ),

                        // Show live timer and message only AFTER check-in
                        if (_hasCheckedIn) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 30),
                            child: GlitchText(
                              key: const ValueKey('timer-message-glitch'),
                              textSpan: _buildTimerMessageSpan(
                                _timerMessage.isNotEmpty
                                    ? _timerMessage
                                    : _fallbackTimerMessage(),
                              ),
                              textAlign: TextAlign.center,
                              glitchInterval: const Duration(seconds: 3),
                              glitchDuration: const Duration(milliseconds: 80),
                            ),
                          ),

                          // "check back in tomorrow" message with typewriter effect
                          const SizedBox(height: 14),
                          TypewriterText(
                            key: const ValueKey('typewriter-tomorrow'),
                            text: 'CHECK BACK IN TOMORROW',
                            charDuration: const Duration(milliseconds: 40),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 15,
                              color: Colors.red.withValues(alpha: 0.9),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Animated "ARE YOU ALIVE?" loop positioned just above the bottom pill
          Positioned(
            left: 0,
            right: 0,
            bottom: 88 + MediaQuery.of(context).padding.bottom,
            child: const IgnorePointer(
              ignoring: true,
              child: Center(
                child: SizedBox(
                  height: 96,
                  child: AreYouAliveLoop(),
                ),
              ),
            ),
          ),
          if (_badgeSnapshot != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16 + MediaQuery.of(context).padding.bottom,
              child: Center(
                child: BottomActionPill(
                  key: const ValueKey('bottom-action-pill'),
                  onShareTap: _openShareSheet,
                  onBadgeTap: _openBadgesScreen,
                  onBuilderTap: _openBuiltByProfile,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageRange {
  const _MessageRange({required this.start, required this.end});

  final int start;
  final int end;
}
