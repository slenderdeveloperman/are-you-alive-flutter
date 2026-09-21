import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/emergency_contact_models.dart';
import '../services/emergency_contact_service.dart';
import '../services/pairing_service.dart';
import '../widgets/animated_button.dart';
import '../theme/bureau_tokens.dart';

class EmergencyContactScreen extends StatefulWidget {
  const EmergencyContactScreen({
    super.key,
    required this.userName,
    EmergencyContactService? service,
    PairingService? pairingService,
    Future<Contact?> Function()? contactPicker,
  }) : _service = service,
       _pairingService = pairingService,
       _contactPicker = contactPicker;

  final String userName;
  final EmergencyContactService? _service;
  final PairingService? _pairingService;
  final Future<Contact?> Function()? _contactPicker;

  @override
  State<EmergencyContactScreen> createState() => _EmergencyContactScreenState();
}

class _EmergencyContactScreenState extends State<EmergencyContactScreen> {
  late final EmergencyContactService _service;
  late final PairingService _pairingService;
  late final Future<Contact?> Function() _pickContact;

  EmergencyContactState? _state;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = widget._service ?? EmergencyContactService();
    _pairingService = widget._pairingService ?? PairingService();
    _pickContact =
        widget._contactPicker ??
        () => FlutterNativeContactPicker().selectPhoneNumber();
    _load();
  }

  /// Best-effort registration of the invite with the backend. Repeat calls
  /// are safe: the server replaces this device's own unclaimed invite. A
  /// `false` result means the code collided or was rejected — regenerate
  /// once and persist the new code. Network failure (null) is ignored;
  /// the next nudge tap retries.
  Future<void> _registerInvite(EmergencyContactState state) async {
    final deviceId = await _service.getOrCreateDeviceId();
    final capability = await _service.getOrCreateWatchdogCapability();
    final created = await _pairingService.createInvite(
      code: state.pairingCode,
      inviterId: deviceId,
      inviterCapability: capability,
    );
    if (created != false) return;

    final regenerated = EmergencyContactState(
      name: state.name,
      phone: state.phone,
      pairingCode: _service.generatePairingCode(),
      status: PairingStatus.pending,
    );
    await _service.save(regenerated);
    if (mounted) {
      setState(() {
        _state = regenerated;
      });
    }
    await _pairingService.createInvite(
      code: regenerated.pairingCode,
      inviterId: deviceId,
      inviterCapability: capability,
    );
  }

  Future<void> _load() async {
    // Phase D: refresh against the backend before rendering, so opening
    // this screen shows current status rather than a stale pending state.
    await _service.syncStatus(_pairingService);
    final state = await _service.load();
    if (!mounted) return;
    setState(() {
      _state = state;
      _loading = false;
    });
  }

  Future<void> _chooseContact() async {
    Contact? contact;
    try {
      contact = await _pickContact();
    } catch (_) {
      contact = null;
    }
    if (contact == null) return; // User cancelled the picker.

    final phone =
        contact.selectedPhoneNumber ??
        (contact.phoneNumbers?.isNotEmpty == true
            ? contact.phoneNumbers!.first
            : null);
    if (phone == null || phone.trim().isEmpty) {
      _showSnack('That contact has no phone number.');
      return;
    }

    final state = EmergencyContactState(
      name: contact.fullName?.trim().isNotEmpty == true
          ? contact.fullName!.trim()
          : 'Your contact',
      phone: phone,
      pairingCode: _service.generatePairingCode(),
      status: PairingStatus.pending,
    );
    await _service.save(state);
    if (!mounted) return;
    setState(() {
      _state = state;
    });
    unawaited(_registerInvite(state));
  }

  Future<void> _sendNudge() async {
    var state = _state;
    if (state == null) return;

    // Awaited (not fire-and-forget): a code collision regenerates the
    // code, and the message must carry whatever code ends up stored.
    await _registerInvite(state);
    state = _state ?? state;

    final message = _service.buildInviteMessage(
      userName: widget.userName,
      code: state.pairingCode,
    );

    // Deep-link path is an optimization; the share sheet needs no number
    // at all and is the correctness fallback (plan 009).
    final digits = _service.normalizeToWhatsAppDigits(state.phone);
    if (digits != null) {
      final uri = _service.buildWhatsAppUri(digits: digits, message: message);
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      } catch (_) {
        // Fall through to the share sheet.
      }
    }

    await Share.share(message, subject: 'Are You Alive?');
  }

  Future<void> _markManuallyConfirmed() async {
    final state = _state;
    if (state == null) return;
    final updated = state.copyWith(
      status: PairingStatus.confirmed,
      manuallyConfirmed: true,
    );
    await _service.save(updated);
    if (!mounted) return;
    setState(() {
      _state = updated;
    });
  }

  Future<void> _removeContact() async {
    final state = _state;
    if (state != null) {
      final deviceId = await _service.getOrCreateDeviceId();
      final capability = await _service.getOrCreateWatchdogCapability();
      // Server revocation is best-effort so an offline subject can still
      // remove the local relationship immediately. A later server cleanup
      // remains an operational concern if this call cannot reach Neon.
      await _pairingService.revokePairing(
        code: state.pairingCode,
        inviterId: deviceId,
        inviterCapability: capability,
      );
    }
    await _service.clear();
    if (!mounted) return;
    setState(() {
      _state = null;
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BureauTokens.ink,
      appBar: AppBar(
        backgroundColor: BureauTokens.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'designated witness',
          style: TextStyle(
            fontFamily: 'monospace',
            letterSpacing: 2,
            fontSize: 14,
            color: BureauTokens.paper,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: BureauTokens.accent),
                )
              : _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final state = _state;
    if (state == null) return _buildEmptyState();
    return state.status == PairingStatus.confirmed
        ? _buildConfirmedState(state)
        : _buildPendingState(state);
  }

  Widget _buildEmptyState() {
    return Column(
      key: const ValueKey('emergency-empty-state'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(
          Icons.shield_outlined,
          size: 56,
          color: Colors.white.withValues(alpha: 0.85),
        ),
        const SizedBox(height: 24),
        Text(
          'Designate one witness to pair with your record.\n\n'
          'Pairing confirms who you trust; automatic missed-deadline '
          'alerts are not active yet.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 15,
            height: 1.6,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const Spacer(),
        _primaryButton(
          key: const ValueKey('emergency-choose-button'),
          label: 'DESIGNATE WITNESS',
          onPressed: _chooseContact,
        ),
      ],
    );
  }

  Widget _buildPendingState(EmergencyContactState state) {
    return Column(
      key: const ValueKey('emergency-pending-state'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Text(
          'WITNESS / PENDING',
          textAlign: TextAlign.center,
          style: BureauTokens.filingLabel.copyWith(
            color: BureauTokens.mutedOnInk,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Awaiting ${state.name}',
          key: const ValueKey('emergency-pending-title'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Invite code',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          state.pairingCode,
          key: const ValueKey('emergency-pairing-code'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 22,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
            color: BureauTokens.accent,
          ),
        ),
        const Spacer(),
        _primaryButton(
          key: const ValueKey('emergency-nudge-button'),
          label: 'SEND WHATSAPP NUDGE',
          onPressed: _sendNudge,
        ),
        const SizedBox(height: 10),
        TextButton(
          key: const ValueKey('emergency-manual-confirm'),
          onPressed: _markManuallyConfirmed,
          child: Text(
            'they told me they installed it',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
        _changeContactButton(),
      ],
    );
  }

  Widget _buildConfirmedState(EmergencyContactState state) {
    return Column(
      key: const ValueKey('emergency-confirmed-state'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const Icon(
          Icons.verified_outlined,
          size: 56,
          color: BureauTokens.active,
        ),
        const SizedBox(height: 24),
        Text(
          '${state.name} / WITNESS CONFIRMED',
          key: const ValueKey('emergency-confirmed-title'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        if (state.manuallyConfirmed) ...[
          const SizedBox(height: 8),
          Text(
            'confirmed by you — not yet verified',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
        const Spacer(),
        _changeContactButton(),
      ],
    );
  }

  Widget _changeContactButton() {
    return TextButton(
      key: const ValueKey('emergency-remove-button'),
      onPressed: _removeContact,
      child: Text(
        'change witness',
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required Key key,
    required String label,
    required VoidCallback onPressed,
  }) {
    return AnimatedButton(
      key: key,
      onPressed: onPressed,
      enableGlow: false,
      pressedScale: 0.98,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: BureauTokens.paper,
          border: Border.all(color: BureauTokens.paper),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: BureauTokens.filingLabel.copyWith(
            fontSize: 13,
            letterSpacing: 1.5,
            color: BureauTokens.ink,
          ),
        ),
      ),
    );
  }
}
