import 'package:flutter/material.dart';

import '../models/share_models.dart';
import 'near_miss_background_painter.dart';
import 'terminal_texture_painter.dart';

class ProgressShareCard extends StatelessWidget {
  const ProgressShareCard({super.key, required this.content});

  final ShareContent content;

  @override
  Widget build(BuildContext context) {
    final textStyle = _textStyleForTheme(content.preset.theme);

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final zone = _zoneForTheme(
            content.preset.theme,
            width: width,
            height: height,
          );
          final horizontalInset = zone.horizontalInset;
          final topInset = zone.topInset;
          final bottomInset = zone.bottomInset;
          final zoneHeight = (height - topInset - bottomInset).clamp(
            1.0,
            height,
          );
          final maxTextWidth = (width - (horizontalInset * 2)).clamp(1.0, width);
          final fitted = _fitTextLayout(
            lines: content.imageLines.take(5).toList(),
            baseStyle: textStyle,
            maxWidth: maxTextWidth,
            maxHeight: zoneHeight,
            baseLineGap: zone.lineGap,
          );

          final textTop =
              topInset + ((zoneHeight - fitted.totalHeight).clamp(0.0, zoneHeight) / 2);
          final textBottom = (height - textTop - fitted.totalHeight)
              .clamp(0.0, height)
              .toDouble();

          final scrimTop = (textTop - (height * 0.04))
              .clamp(0.0, height - 1)
              .toDouble();
          final scrimBottom = (textBottom - (height * 0.03))
              .clamp(0.0, height - 1)
              .toDouble();

          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(color: Colors.white),
                ),
                Positioned.fill(
                  child: content.preset.backgroundAssetPath.isEmpty
                      ? const Stack(
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(painter: NearMissBackgroundPainter()),
                            CustomPaint(painter: TerminalTexturePainter()),
                          ],
                        )
                      : Image.asset(
                          content.preset.backgroundAssetPath,
                          fit: BoxFit.contain,
                          alignment: Alignment.topCenter,
                        ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: scrimTop,
                  bottom: scrimBottom,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.black.withValues(alpha: 0),
                            Colors.black.withValues(alpha: 0.22),
                            Colors.black.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: textTop,
                  bottom: textBottom,
                  left: horizontalInset,
                  right: horizontalInset,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < fitted.lines.length; i++) ...[
                        if (i > 0) SizedBox(height: fitted.lineGap),
                        Text(
                          fitted.lines[i],
                          style: fitted.style,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  _TextZone _zoneForTheme(
    ShareTheme theme, {
    required double width,
    required double height,
  }) {
    final horizontalInset = (width * 0.078).clamp(20.0, 34.0).toDouble();

    switch (theme) {
      case ShareTheme.certificate:
        return _TextZone(
          horizontalInset: horizontalInset,
          topInset: (height * 0.59).clamp(260.0, 470.0).toDouble(),
          bottomInset: (height * 0.17).clamp(90.0, 155.0).toDouble(),
          lineGap: (height * 0.012).clamp(5.0, 8.0).toDouble(),
        );
      case ShareTheme.battery:
        return _TextZone(
          horizontalInset: horizontalInset,
          topInset: (height * 0.28).clamp(140.0, 220.0).toDouble(),
          bottomInset: (height * 0.30).clamp(150.0, 230.0).toDouble(),
          lineGap: (height * 0.014).clamp(6.0, 10.0).toDouble(),
        );
      case ShareTheme.timeServed:
      case ShareTheme.proofOfLife:
        return _TextZone(
          horizontalInset: horizontalInset,
          topInset: (height * 0.27).clamp(130.0, 210.0).toDouble(),
          bottomInset: (height * 0.30).clamp(150.0, 230.0).toDouble(),
          lineGap: (height * 0.014).clamp(6.0, 10.0).toDouble(),
        );
      case ShareTheme.nearMiss:
        return _TextZone(
          horizontalInset: horizontalInset,
          topInset: (height * 0.30).clamp(150.0, 230.0).toDouble(),
          bottomInset: (height * 0.28).clamp(140.0, 220.0).toDouble(),
          lineGap: (height * 0.016).clamp(6.0, 11.0).toDouble(),
        );
    }
  }

  _FittedTextLayout _fitTextLayout({
    required List<String> lines,
    required TextStyle baseStyle,
    required double maxWidth,
    required double maxHeight,
    required double baseLineGap,
  }) {
    if (lines.isEmpty) {
      return _FittedTextLayout(
        lines: const <String>[],
        style: baseStyle,
        lineGap: baseLineGap,
        totalHeight: 0,
      );
    }

    const scaleCandidates = <double>[1.0, 0.96, 0.92, 0.88, 0.84, 0.8, 0.76];

    for (final scale in scaleCandidates) {
      final scaledFontSize = ((baseStyle.fontSize ?? 14) * scale).clamp(12.0, 40.0);
      final scaledStyle = baseStyle.copyWith(fontSize: scaledFontSize.toDouble());
      final scaledGap = (baseLineGap * scale).clamp(4.0, 12.0).toDouble();

      for (var count = lines.length; count >= 1; count--) {
        final isTruncated = count < lines.length;
        final candidate = lines.take(count).toList();
        if (isTruncated) {
          candidate[candidate.length - 1] = '${candidate.last}…';
        }

        final total = _measureTextBlockHeight(
          lines: candidate,
          style: scaledStyle,
          maxWidth: maxWidth,
          lineGap: scaledGap,
        );

        if (total <= maxHeight) {
          return _FittedTextLayout(
            lines: candidate,
            style: scaledStyle,
            lineGap: scaledGap,
            totalHeight: total,
          );
        }
      }
    }

    final fallbackStyle = baseStyle.copyWith(fontSize: 12);
    final fallbackLine = '${lines.first}…';
    final fallbackHeight = _measureTextBlockHeight(
      lines: <String>[fallbackLine],
      style: fallbackStyle,
      maxWidth: maxWidth,
      lineGap: 4,
    );

    return _FittedTextLayout(
      lines: <String>[fallbackLine],
      style: fallbackStyle,
      lineGap: 4,
      totalHeight: fallbackHeight,
    );
  }

  double _measureTextBlockHeight({
    required List<String> lines,
    required TextStyle style,
    required double maxWidth,
    required double lineGap,
  }) {
    var total = 0.0;
    for (var i = 0; i < lines.length; i++) {
      final painter = TextPainter(
        text: TextSpan(text: lines[i], style: style),
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
      total += painter.height;
      if (i < lines.length - 1) {
        total += lineGap;
      }
    }
    return total;
  }

  TextStyle _textStyleForTheme(ShareTheme theme) {
    switch (theme) {
      case ShareTheme.certificate:
        return const TextStyle(
          fontFamily: 'Georgia',
          fontSize: 19,
          height: 1.28,
          color: Color(0xFF171717),
          shadows: <Shadow>[
            Shadow(
              color: Color(0x26000000),
              blurRadius: 1.2,
              offset: Offset(0, 0.6),
            ),
          ],
        );
      case ShareTheme.battery:
        return const TextStyle(
          fontFamily: 'monospace',
          fontSize: 20,
          height: 1.34,
          color: Color(0xFF031A03),
          fontWeight: FontWeight.w600,
          shadows: <Shadow>[
            Shadow(
              color: Color(0x24000000),
              blurRadius: 1.2,
              offset: Offset(0, 0.6),
            ),
          ],
        );
      case ShareTheme.timeServed:
        return const TextStyle(
          fontFamily: 'monospace',
          fontSize: 21,
          height: 1.32,
          color: Color(0xFF111111),
          fontWeight: FontWeight.w600,
          shadows: <Shadow>[
            Shadow(
              color: Color(0x24000000),
              blurRadius: 1.2,
              offset: Offset(0, 0.6),
            ),
          ],
        );
      case ShareTheme.proofOfLife:
        return const TextStyle(
          fontFamily: 'monospace',
          fontSize: 20,
          height: 1.34,
          color: Color(0xFF1A120A),
          fontWeight: FontWeight.w700,
          shadows: <Shadow>[
            Shadow(
              color: Color(0x24000000),
              blurRadius: 1.2,
              offset: Offset(0, 0.6),
            ),
          ],
        );
      case ShareTheme.nearMiss:
        return const TextStyle(
          fontFamily: 'monospace',
          fontSize: 21,
          height: 1.3,
          color: Colors.white,
          fontWeight: FontWeight.w700,
          shadows: <Shadow>[
            Shadow(
              color: Color(0xFFEF4444),
              blurRadius: 6,
              offset: Offset(0, 0),
            ),
          ],
        );
    }
  }
}

class _TextZone {
  const _TextZone({
    required this.horizontalInset,
    required this.topInset,
    required this.bottomInset,
    required this.lineGap,
  });

  final double horizontalInset;
  final double topInset;
  final double bottomInset;
  final double lineGap;
}

class _FittedTextLayout {
  const _FittedTextLayout({
    required this.lines,
    required this.style,
    required this.lineGap,
    required this.totalHeight,
  });

  final List<String> lines;
  final TextStyle style;
  final double lineGap;
  final double totalHeight;
}
