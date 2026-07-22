import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/emergency_contact_service.dart';
import '../services/invite_claim_service.dart';
import '../services/pairing_service.dart';
import '../theme/app_layout.dart';
import '../widgets/animated_button.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.onComplete,
    EmergencyContactService? emergencyContactService,
    PairingService? pairingService,
    InviteClaimService? inviteClaimService,
  }) : _emergencyContactService = emergencyContactService,
       _pairingService = pairingService,
       _inviteClaimService = inviteClaimService;

  final VoidCallback onComplete;
  final EmergencyContactService? _emergencyContactService;
  final PairingService? _pairingService;
  final InviteClaimService? _inviteClaimService;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isNameValid = false;

  late final EmergencyContactService _emergencyContactService;
  late final PairingService _pairingService;
  late final InviteClaimService _inviteClaimService;
  String? _detectedCode;

  @override
  void initState() {
    super.initState();
    _emergencyContactService =
        widget._emergencyContactService ?? EmergencyContactService();
    _pairingService = widget._pairingService ?? PairingService();
    _inviteClaimService = widget._inviteClaimService ?? const InviteClaimService();
    _nameController.addListener(_validateName);
    _detectReferrerCode();
  }

  Future<void> _detectReferrerCode() async {
    final code = await _inviteClaimService.detectReferrerCode();
    if (!mounted || code == null) return;
    setState(() {
      _detectedCode = code;
    });
  }

  void _validateName() {
    setState(() {
      _isNameValid = _nameController.text.trim().isNotEmpty;
    });
  }

  Future<void> _proceed() async {
    if (!_isNameValid) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', _nameController.text.trim());
    await prefs.setBool('hasCompletedOnboarding', true);

    widget.onComplete();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _openInviteCodeSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _InviteCodeSheet(
        initialCode: _detectedCode,
        claimerName: _nameController.text,
        emergencyContactService: _emergencyContactService,
        pairingService: _pairingService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppLayout.buttonHorizontalGutter,
          ),
          child: Column(
            children: [
              const Spacer(),

              // Title
              Text(
                'identify yourself',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 22,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 4,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),

              const SizedBox(height: 40),

              // Input field
              Row(
                children: [
                  Text(
                    '> ',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      color: Colors.red.withValues(alpha: 0.7),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                      ),
                      cursorColor: Colors.red,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '',
                      ),
                    ),
                  ),
                ],
              ),

              // Divider
              Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),

              const Spacer(),

              // Proceed button with scale + glow animation
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.buttonMaxWidth,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: AppLayout.buttonHeight,
                  child: AnimatedButton(
                    onPressed: _isNameValid ? _proceed : null,
                    glowColor: Colors.red,
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        color: _isNameValid
                            ? Colors.red.withValues(alpha: 0.8)
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        'proceed',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          letterSpacing: 3,
                          color: _isNameValid
                              ? Colors.black
                              : Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              TextButton(
                key: const ValueKey('welcome-invite-code-button'),
                onPressed: _openInviteCodeSheet,
                child: Text(
                  'have an invite code?',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    letterSpacing: 1,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),

              const SizedBox(height: 64),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for plan 009 Phase C: accept an emergency-contact invite,
/// either auto-filled from the Play install referrer or typed by hand.
class _InviteCodeSheet extends StatefulWidget {
  const _InviteCodeSheet({
    required this.initialCode,
    required this.claimerName,
    required this.emergencyContactService,
    required this.pairingService,
  });

  final String? initialCode;
  final String claimerName;
  final EmergencyContactService emergencyContactService;
  final PairingService pairingService;

  @override
  State<_InviteCodeSheet> createState() => _InviteCodeSheetState();
}

class _InviteCodeSheetState extends State<_InviteCodeSheet> {
  late final TextEditingController _codeController;
  bool _submitting = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.initialCode ?? '');
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() {
      _submitting = true;
      _message = null;
    });

    final deviceId = await widget.emergencyContactService.getOrCreateDeviceId();
    final result = await widget.pairingService.claimInvite(
      code: code,
      claimerId: deviceId,
      claimerName: widget.claimerName.trim().isEmpty
          ? null
          : widget.claimerName.trim(),
    );

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _message = switch (result) {
        ClaimResult.claimed => 'Accepted — you\'re their emergency contact.',
        ClaimResult.alreadyClaimed => 'This invite was already accepted.',
        ClaimResult.notFound => 'That code doesn\'t match an active invite.',
        null => 'Couldn\'t reach the server — check your connection.',
      };
    });

    if (result == ClaimResult.claimed) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF090909),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Someone chose you as their emergency contact.',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('welcome-invite-code-field'),
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 18,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  hintText: 'AYA-XXXXXX',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  key: const ValueKey('welcome-invite-code-message'),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                key: const ValueKey('welcome-invite-code-accept'),
                onPressed: _submitting ? null : _accept,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                child: Text(_submitting ? 'Checking…' : 'Accept'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
