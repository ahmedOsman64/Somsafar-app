import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../core/services/supabase_service.dart';

final forgotPasswordProvider = Provider((ref) => ForgotPasswordService());

class ForgotPasswordService {
  Future<void> sendOtp(String email) async {
    try {
      await SupabaseConfig.client.auth.resetPasswordForEmail(email);
    } on sb.AuthException catch (e) {
      if (e.message.toLowerCase().contains('not found') || 
          e.message.toLowerCase().contains('no user')) {
        throw Exception('No account found with this email');
      }
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to send reset code.');
    }
  }

  Future<void> verifyOtp(String email, String otp) async {
    try {
      await SupabaseConfig.client.auth.verifyOTP(
        type: sb.OtpType.recovery,
        token: otp,
        email: email,
      );
    } on sb.AuthException catch (e) {
      if (e.message.toLowerCase().contains('expired')) {
        throw Exception('Code expired, request a new one');
      }
      throw Exception('Invalid verification code');
    } catch (e) {
      throw Exception('Invalid verification code');
    }
  }

  Future<void> updatePassword(String email, String newPassword) async {
    try {
      await SupabaseConfig.client.auth.updateUser(
        sb.UserAttributes(password: newPassword),
      );
    } on sb.AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Failed to update password.');
    }
  }
}
