import 'package:flutter/material.dart';

import '../theme/bureau_tokens.dart';

class FilingField {
  const FilingField(this.label, this.value);
  final String label;
  final String value;
}

/// Shared F.C.C.D.B. identity primitive.
/// This is deliberately structural rather than logo-like so it can recur in
/// the app, ESTD. INDICA dossiers, share extracts and physical artifacts.
class FilingBlock extends StatelessWidget {
  const FilingBlock({
    super.key,
    this.file = 'FLD-AYA-01',
    required this.status,
    this.revision = '03',
    this.fields = const <FilingField>[],
    this.inverted = true,
  });

  final String file;
  final String status;
  final String revision;
  final List<FilingField> fields;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final foreground = inverted ? BureauTokens.paper : BureauTokens.ink;
    final rule = inverted ? BureauTokens.ruleOnInk : BureauTokens.ruleOnPaper;

    final rows = <FilingField>[
      FilingField('FILE', file),
      FilingField('STATUS', status),
      FilingField('REVISION', revision),
      ...fields,
    ];

    return Container(
      key: const ValueKey('filing-block'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: rule)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'F.C.C.D.B.',
            style: BureauTokens.filingLabel.copyWith(color: foreground),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 13, thickness: 1, color: rule),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 74,
                  child: Text(
                    rows[i].label,
                    style: BureauTokens.filingLabel.copyWith(color: foreground),
                  ),
                ),
                Expanded(
                  child: Text(
                    rows[i].value,
                    textAlign: TextAlign.right,
                    style: BureauTokens.filingValue.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact filing identity used on shareable register extracts.
///
/// The stamp keeps the same file/status/revision geometry as [FilingBlock]
/// while fitting over artwork without becoming a second full panel.
class FilingStamp extends StatelessWidget {
  const FilingStamp({
    super.key,
    required this.status,
    this.file = 'FLD-AYA-01',
    this.revision = '03',
    this.inverted = false,
  });

  final String file;
  final String status;
  final String revision;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final foreground = inverted ? BureauTokens.paper : BureauTokens.ink;
    final rule = inverted ? BureauTokens.ruleOnInk : BureauTokens.ruleOnPaper;

    return Container(
      key: const ValueKey('filing-stamp'),
      width: 132,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: inverted
            ? BureauTokens.ink.withValues(alpha: 0.82)
            : BureauTokens.paper.withValues(alpha: 0.86),
        border: Border.all(color: rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'F.C.C.D.B.',
            style: BureauTokens.filingLabel.copyWith(
              color: foreground,
              fontSize: 8,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          _StampRow(label: 'FILE', value: file, color: foreground),
          Divider(height: 7, thickness: 1, color: rule),
          _StampRow(label: 'STATUS', value: status, color: foreground),
          Divider(height: 7, thickness: 1, color: rule),
          _StampRow(label: 'REV', value: revision, color: foreground),
        ],
      ),
    );
  }
}

class _StampRow extends StatelessWidget {
  const _StampRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: BureauTokens.filingLabel.copyWith(
            color: color,
            fontSize: 7,
            letterSpacing: 0.5,
          ),
        ),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BureauTokens.filingValue.copyWith(color: color, fontSize: 8),
          ),
        ),
      ],
    );
  }
}
