import 'dart:async';
import 'package:flutter/material.dart';

/// A text widget that reveals characters one by one like a typewriter.
///
/// Features:
/// - Configurable speed per character (default 40ms)
/// - Optional blinking cursor at the end
/// - Callback when typing completes
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration charDuration;
  final bool showCursor;
  final VoidCallback? onComplete;
  final TextAlign textAlign;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.charDuration = const Duration(milliseconds: 40),
    this.showCursor = false,
    this.onComplete,
    this.textAlign = TextAlign.start,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayedText = '';
  Timer? _typingTimer;
  Timer? _cursorBlinkTimer;
  int _charIndex = 0;
  bool _showCursorBlink = true;

  @override
  void initState() {
    super.initState();
    _startTyping();
    if (widget.showCursor) {
      _startCursorBlink();
    }
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Restart typing if text changes
    if (oldWidget.text != widget.text) {
      _typingTimer?.cancel();
      _charIndex = 0;
      _displayedText = '';
      _startTyping();
    }
  }

  void _startTyping() {
    // Handle empty text
    if (widget.text.isEmpty) {
      widget.onComplete?.call();
      return;
    }

    _typingTimer = Timer.periodic(widget.charDuration, (timer) {
      if (_charIndex < widget.text.length) {
        setState(() {
          _charIndex++;
          _displayedText = widget.text.substring(0, _charIndex);
        });
      } else {
        timer.cancel();
        widget.onComplete?.call();
      }
    });
  }

  void _startCursorBlink() {
    _cursorBlinkTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() {
        _showCursorBlink = !_showCursorBlink;
      });
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _cursorBlinkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cursorChar = widget.showCursor && _showCursorBlink ? '_' : '';

    return Text(
      _displayedText + cursorChar,
      style: widget.style,
      textAlign: widget.textAlign,
    );
  }
}
