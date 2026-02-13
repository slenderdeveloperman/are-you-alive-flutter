import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// A widget that displays a TextSpan with occasional "glitch" effects
/// where random characters are briefly replaced with symbols.
class GlitchText extends StatefulWidget {
  const GlitchText({
    super.key,
    required this.textSpan,
    this.glitchInterval = const Duration(seconds: 3),
    this.glitchDuration = const Duration(milliseconds: 80),
    this.textAlign = TextAlign.start,
  });

  /// The original TextSpan to display (preserves existing styling).
  final TextSpan textSpan;

  /// How often glitches occur (randomized around this value).
  final Duration glitchInterval;

  /// How long each glitch lasts before restoring original text.
  final Duration glitchDuration;

  /// Text alignment for the rich text.
  final TextAlign textAlign;

  @override
  State<GlitchText> createState() => _GlitchTextState();
}

class _GlitchTextState extends State<GlitchText> {
  static const _glitchChars = ['#', '@', '%', '&', '!', '?', '*', '^', '~'];
  final _random = Random();
  Timer? _glitchTimer;
  Timer? _restoreTimer;

  /// Positions of characters currently being glitched.
  List<int> _glitchPositions = [];

  /// The glitched character replacements.
  Map<int, String> _glitchReplacements = {};

  @override
  void initState() {
    super.initState();
    _scheduleNextGlitch();
  }

  @override
  void didUpdateWidget(GlitchText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset glitch state when text changes
    if (_extractPlainText(oldWidget.textSpan) !=
        _extractPlainText(widget.textSpan)) {
      _glitchPositions = [];
      _glitchReplacements = {};
    }
  }

  @override
  void dispose() {
    _glitchTimer?.cancel();
    _restoreTimer?.cancel();
    super.dispose();
  }

  void _scheduleNextGlitch() {
    _glitchTimer?.cancel();

    // Randomize interval: 2-4 seconds around the base interval
    final variance = widget.glitchInterval.inMilliseconds ~/ 2;
    final delay = Duration(
      milliseconds: widget.glitchInterval.inMilliseconds +
          _random.nextInt(variance * 2) -
          variance,
    );

    _glitchTimer = Timer(delay, _triggerGlitch);
  }

  void _triggerGlitch() {
    if (!mounted) return;

    final plainText = _extractPlainText(widget.textSpan);
    if (plainText.isEmpty) {
      _scheduleNextGlitch();
      return;
    }

    // Find positions that are NOT highlighted (red text)
    final safePositions = _findNonHighlightedPositions(widget.textSpan);
    if (safePositions.isEmpty) {
      _scheduleNextGlitch();
      return;
    }

    // Pick 1-3 random positions to glitch
    final numGlitches = 1 + _random.nextInt(3);
    final shuffled = List<int>.from(safePositions)..shuffle(_random);
    final positions = shuffled.take(numGlitches).toList();

    // Generate random replacement characters
    final replacements = <int, String>{};
    for (final pos in positions) {
      replacements[pos] = _glitchChars[_random.nextInt(_glitchChars.length)];
    }

    setState(() {
      _glitchPositions = positions;
      _glitchReplacements = replacements;
    });

    // Schedule restoration
    _restoreTimer?.cancel();
    _restoreTimer = Timer(widget.glitchDuration, () {
      if (!mounted) return;
      setState(() {
        _glitchPositions = [];
        _glitchReplacements = {};
      });
      _scheduleNextGlitch();
    });
  }

  /// Extracts plain text from a TextSpan tree.
  String _extractPlainText(TextSpan span) {
    final buffer = StringBuffer();
    span.visitChildren((child) {
      if (child is TextSpan) {
        if (child.text != null) {
          buffer.write(child.text);
        }
      }
      return true;
    });
    if (span.text != null) {
      buffer.write(span.text);
    }
    return buffer.toString();
  }

  /// Returns character indices that are NOT in highlighted (red) spans.
  List<int> _findNonHighlightedPositions(TextSpan rootSpan) {
    final safePositions = <int>[];
    var currentIndex = 0;

    void visitSpan(InlineSpan span, bool isHighlighted) {
      if (span is TextSpan) {
        final text = span.text;
        final spanHighlighted =
            isHighlighted || _isHighlightedStyle(span.style);

        if (text != null) {
          for (var i = 0; i < text.length; i++) {
            if (!spanHighlighted && !text[i].contains(RegExp(r'\s'))) {
              safePositions.add(currentIndex + i);
            }
          }
          currentIndex += text.length;
        }

        span.children?.forEach((child) => visitSpan(child, spanHighlighted));
      }
    }

    visitSpan(rootSpan, false);
    return safePositions;
  }

  /// Checks if a style indicates highlighted text (red color).
  bool _isHighlightedStyle(TextStyle? style) {
    if (style == null || style.color == null) return false;
    final color = style.color!;
    // Check if color is reddish (high red, low green/blue)
    return color.r > 0.7 && color.g < 0.4 && color.b < 0.4;
  }

  /// Builds a new TextSpan with glitched characters.
  TextSpan _buildGlitchedSpan(TextSpan original) {
    if (_glitchPositions.isEmpty) return original;

    var globalIndex = 0;

    TextSpan transformSpan(TextSpan span) {
      final children = <InlineSpan>[];

      if (span.text != null) {
        final text = span.text!;
        final buffer = StringBuffer();

        for (var i = 0; i < text.length; i++) {
          final globalPos = globalIndex + i;
          if (_glitchReplacements.containsKey(globalPos)) {
            buffer.write(_glitchReplacements[globalPos]);
          } else {
            buffer.write(text[i]);
          }
        }
        globalIndex += text.length;

        // Create new span with glitched text but same style
        return TextSpan(
          text: buffer.toString(),
          style: span.style,
          children: span.children
              ?.map((child) {
                if (child is TextSpan) {
                  return transformSpan(child);
                }
                return child;
              })
              .toList(),
        );
      }

      // If no direct text, just transform children
      if (span.children != null) {
        for (final child in span.children!) {
          if (child is TextSpan) {
            children.add(transformSpan(child));
          } else {
            children.add(child);
          }
        }
      }

      return TextSpan(
        style: span.style,
        children: children.isEmpty ? null : children,
      );
    }

    return transformSpan(original);
  }

  @override
  Widget build(BuildContext context) {
    final displaySpan = _buildGlitchedSpan(widget.textSpan);
    return Text.rich(
      displaySpan,
      textAlign: widget.textAlign,
    );
  }
}
