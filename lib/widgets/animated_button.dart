import 'package:flutter/material.dart';

/// A button widget that provides scale feedback on press and a glow pulse on release.
///
/// Press behavior:
/// - Scale to 0.95 with slight opacity reduction (100ms)
///
/// Release behavior:
/// - Scale back to 1.0
/// - Red glow pulse on border that fades out (200ms)
class AnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color glowColor;
  final double pressedScale;
  final Duration pressDuration;
  final Duration glowDuration;

  /// Whether the release glow pulse plays. The glow is the check-in CTA's
  /// identity marker — disable it for lighter-weight tap targets (icon
  /// buttons, grid items) that just need press-scale feedback.
  final bool enableGlow;

  const AnimatedButton({
    super.key,
    required this.child,
    this.onPressed,
    this.glowColor = Colors.red,
    this.pressedScale = 0.95,
    this.pressDuration = const Duration(milliseconds: 100),
    this.glowDuration = const Duration(milliseconds: 200),
    this.enableGlow = true,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: widget.glowDuration,
      vsync: this,
    );
    _glowAnimation = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    if (widget.enableGlow) {
      _glowController.forward(from: 0);
    }
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onPressed != null ? _handleTapDown : null,
      onTapUp: widget.onPressed != null ? _handleTapUp : null,
      onTapCancel: widget.onPressed != null ? _handleTapCancel : null,
      child: AnimatedScale(
        scale: _isPressed ? widget.pressedScale : 1.0,
        duration: widget.pressDuration,
        curve: Curves.easeOut,
        child: !widget.enableGlow
            ? widget.child
            : AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, child) {
                  // Glow intensity decreases as animation progresses (eased)
                  final glowOpacity = (1 - _glowAnimation.value) * 0.5;
                  final glowBlur = 20 * (1 - _glowAnimation.value);
                  final glowSpread = 2 * (1 - _glowAnimation.value);

                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _glowAnimation.value < 1
                          ? [
                              BoxShadow(
                                color: widget.glowColor.withValues(
                                  alpha: glowOpacity,
                                ),
                                blurRadius: glowBlur,
                                spreadRadius: glowSpread,
                              ),
                            ]
                          : null,
                    ),
                    child: child,
                  );
                },
                child: widget.child,
              ),
      ),
    );
  }
}
