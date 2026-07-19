import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

void main() async {
  print('Loading environment variables from assets/env...');
  final file = File('assets/env');
  if (!await file.exists()) {
    print('Error: assets/env file not found!');
    exit(1);
  }

  // Manually parse env file
  final lines = await file.readAsLines();
  final env = <String, String>{};
  for (var line in lines) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final idx = line.indexOf('=');
    if (idx != -1) {
      final key = line.substring(0, idx).trim();
      final val = line.substring(idx + 1).trim();
      env[key] = val;
    }
  }

  final sender = env['EMAIL_SENDER'] ?? 'somsafarbooking@gmail.com';
  final password = env['EMAIL_APP_PASSWORD'] ?? '';

  print('Sender: $sender');
  print('Password: ${password.isNotEmpty ? '********' : '(empty)'}');

  if (password.isEmpty) {
    print('Error: EMAIL_APP_PASSWORD is empty!');
    exit(1);
  }

  final smtpServer = gmail(sender, password);

  final message = Message()
    ..from = Address(sender, 'SomSafar Test')
    ..recipients.add('amaana4045@gmail.com')
    ..subject = 'SomSafar Email Test'
    ..text = 'This is a test email from SomSafar.';

  try {
    print('Sending email...');
    final sendReport = await send(message, smtpServer);
    print('Email sent successfully!');
    print(sendReport);
  } catch (e, stackTrace) {
    print('Error sending email: $e');
    print('Stack trace:\n$stackTrace');
  }
}
