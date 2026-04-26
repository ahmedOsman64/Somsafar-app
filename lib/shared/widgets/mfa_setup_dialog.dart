import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/auth_service.dart';
import '../../core/theme/app_colors.dart';

class MFASetupDialog extends ConsumerStatefulWidget {
  final String qrUri;
  final String secret;
  final String factorId;

  const MFASetupDialog({
    super.key,
    required this.qrUri,
    required this.secret,
    required this.factorId,
  });

  @override
  ConsumerState<MFASetupDialog> createState() => _MFASetupDialogState();
}

class _MFASetupDialogState extends ConsumerState<MFASetupDialog> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _verify() async {
    if (_codeController.text.length != 6) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final error = await ref.read(authServiceProvider).verifyTOTPSetup(
          factorId: widget.factorId,
          code: _codeController.text,
        );

    if (mounted) {
      if (error == null) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _isLoading = false;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            const Text(
              'Set Up 2FA',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D3B66),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Scan this QR code with your authenticator app (like Google Authenticator or Authy).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: QrImageView(
                data: widget.qrUri,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Or enter this secret manually:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            SelectableText(
              widget.secret,
              style: const TextStyle(
                fontSize: 16,
                letterSpacing: 2,
                fontFamily: 'monospace',
                color: Color(0xFF0D3B66),
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '000000',
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.secondary, width: 2),
                ),
              ),
              onChanged: (v) {
                if (v.length == 6) _verify();
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Verify & Enable', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: const Text(
                'Back',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
