import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';

import '../config/share_presets.dart';
import '../models/share_models.dart';
import '../services/progress_share_service.dart';
import 'progress_share_card.dart';

class SharePresetSheet extends StatefulWidget {
  const SharePresetSheet({
    super.key,
    required this.input,
    ProgressShareService? shareService,
  }) : _shareService = shareService;

  final SharePayloadInput input;
  final ProgressShareService? _shareService;

  @override
  State<SharePresetSheet> createState() => _SharePresetSheetState();
}

class _SharePresetSheetState extends State<SharePresetSheet> {
  late final ProgressShareService _shareService;
  final ScreenshotController _screenshotController = ScreenshotController();

  int _stepIndex = 0;
  late SharePreset _selectedPreset;
  late Set<ShareField> _selectedFields;

  ShareContent? _previewContent;
  bool _loadingPreview = false;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _shareService = widget._shareService ?? ProgressShareService();
    _selectedPreset = sharePresets.first;
    _selectedFields = Set<ShareField>.from(_selectedPreset.defaultFields);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.86,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF090909),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                  child: Row(
                    children: [
                      Text(
                        _headerTitle(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'monospace',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                LinearProgressIndicator(
                  minHeight: 2,
                  value: (_stepIndex + 1) / 3,
                  color: Colors.redAccent,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    child: _buildStepBody(),
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Row(
                    children: [
                      if (_stepIndex > 0)
                        TextButton(
                          onPressed: _isSharing ? null : _goBack,
                          child: const Text('Back'),
                        )
                      else
                        const SizedBox(width: 66),
                      const Spacer(),
                      FilledButton(
                        onPressed: _isPrimaryActionEnabled()
                            ? () {
                                switch (_stepIndex) {
                                  case 0:
                                    _goNext();
                                  case 1:
                                    _goNext();
                                  case 2:
                                    _shareNow();
                                }
                              }
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(_primaryButtonText()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepBody() {
    switch (_stepIndex) {
      case 0:
        return _buildPresetPicker();
      case 1:
        return _buildFieldPicker();
      default:
        return _buildPreview();
    }
  }

  Widget _buildPresetPicker() {
    return GridView.builder(
      itemCount: sharePresets.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.64,
      ),
      itemBuilder: (context, index) {
        final preset = sharePresets[index];
        final selected = preset.id == _selectedPreset.id;
        return _buildPresetCard(preset: preset, selected: selected);
      },
    );
  }

  Widget _buildPresetCard({required SharePreset preset, required bool selected}) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      scale: selected ? 1.02 : 1.0,
      child: InkWell(
        key: ValueKey('share-preset-card-${preset.id}'),
        onTap: () {
          setState(() {
            _selectedPreset = preset;
            _selectedFields = Set<ShareField>.from(preset.defaultFields);
            _previewContent = null;
          });
        },
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          key: ValueKey('share-preset-container-${preset.id}'),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.18),
              width: selected ? 2.0 : 1.0,
            ),
            color: selected
                ? Colors.white.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.04),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.32),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    preset.thumbnailAssetPath,
                    key: ValueKey('share-preset-thumb-${preset.id}'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                preset.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.88),
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldPicker() {
    final allFields = _selectedPreset.allFields.toList();

    return ListView(
      children: [
        Text(
          'Pick what to include. Sensitive fields are off by default.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        ...allFields.map((field) {
          final enabled = _selectedFields.contains(field);
          final required = _selectedPreset.defaultFields.contains(field);

          return SwitchListTile(
            value: enabled,
            onChanged: required
                ? null
                : (value) {
                    setState(() {
                      if (value) {
                        _selectedFields.add(field);
                      } else {
                        _selectedFields.remove(field);
                      }
                      _previewContent = null;
                    });
                  },
            activeThumbColor: Colors.redAccent,
            activeTrackColor: Colors.red.withValues(alpha: 0.4),
            title: Text(
              _labelForField(field),
              style: TextStyle(
                color: required
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.9),
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
            subtitle: required
                ? Text(
                    'Required by this preset',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  )
                : null,
          );
        }),
      ],
    );
  }

  Widget _buildPreview() {
    if (_loadingPreview) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.redAccent),
      );
    }

    if (_previewContent == null) {
      return Center(
        child: Text(
          'Preview unavailable.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontFamily: 'monospace',
          ),
        ),
      );
    }

    return ListView(
      children: [
        Screenshot(
          controller: _screenshotController,
          child: ProgressShareCard(content: _previewContent!),
        ),
        const SizedBox(height: 12),
        Text(
          'Caption preview',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _previewContent!.caption,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontFamily: 'monospace',
            height: 1.35,
          ),
        ),
      ],
    );
  }

  void _goBack() {
    if (_stepIndex == 0) return;
    setState(() {
      _stepIndex -= 1;
    });
  }

  Future<void> _goNext() async {
    if (_stepIndex == 0) {
      setState(() {
        _stepIndex = 1;
      });
      return;
    }

    if (_stepIndex == 1) {
      setState(() {
        _stepIndex = 2;
      });
      await _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    setState(() {
      _loadingPreview = true;
    });

    final content = await _shareService.buildContent(
      preset: _selectedPreset,
      selectedFields: _selectedFields,
      input: widget.input,
    );

    if (!mounted) return;
    setState(() {
      _previewContent = content;
      _loadingPreview = false;
    });
  }

  Future<void> _shareNow() async {
    if (_previewContent == null || _isSharing) return;

    setState(() {
      _isSharing = true;
    });

    Uint8List? imageBytes;
    try {
      imageBytes = await _screenshotController.capture(pixelRatio: 2);
    } catch (_) {
      imageBytes = null;
    }

    try {
      await _shareService.shareProgress(
        caption: _previewContent!.caption,
        imageBytes: imageBytes,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Share failed. Try again.')));
      setState(() {
        _isSharing = false;
      });
    }
  }

  String _primaryButtonText() {
    if (_stepIndex == 2) {
      return _isSharing ? 'Sharing...' : 'Share now';
    }
    return 'Continue';
  }

  bool _isPrimaryActionEnabled() {
    if (_stepIndex == 2) {
      return !_isSharing && !_loadingPreview;
    }
    return true;
  }

  String _headerTitle() {
    switch (_stepIndex) {
      case 0:
        return 'Choose Preset';
      case 1:
        return 'Pick Data';
      default:
        return 'Preview & Share';
    }
  }

  String _labelForField(ShareField field) {
    switch (field) {
      case ShareField.cumulativeHours:
        return 'Total cumulative hours';
      case ShareField.rankTitle:
        return 'Current rank/title';
      case ShareField.checkInMargin:
        return 'Check-in margin';
      case ShareField.stabilityStatus:
        return 'Stability status';
      case ShareField.nextDeadline:
        return 'Next deadline';
      case ShareField.streakDays:
        return 'Streak days';
      case ShareField.tallyGroups:
        return 'Tally marks';
      case ShareField.userName:
        return 'User name';
      case ShareField.proofTimestamp:
        return 'Proof timestamp';
    }
  }
}
