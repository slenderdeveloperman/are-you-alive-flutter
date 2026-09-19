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
