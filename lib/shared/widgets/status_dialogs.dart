import 'package:flutter/material.dart';

class StatusDialog extends StatelessWidget {
  final bool isSuccess;
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback onButtonPressed;

  const StatusDialog({
    super.key,
    required this.isSuccess,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onButtonPressed,
  });

  static void show(
    BuildContext context, {
    required bool isSuccess,
    required String title,
    required String message,
    String? buttonText,
    VoidCallback? onButtonPressed,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: StatusDialog(
          isSuccess: isSuccess,
          title: title,
          message: message,
          buttonText: buttonText ?? (isSuccess ? 'Done!' : 'Opps!'),
          onButtonPressed: onButtonPressed ?? () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? const Color(0xFF2ECC71) : const Color(0xFFFF7675);
    final lightColor = color.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Background confetti-like shapes (simplified for performance)
          Positioned(
            top: -10,
            right: 0,
            child: Icon(Icons.circle, color: Colors.blue.withValues(alpha: 0.2), size: 12),
          ),
          Positioned(
            top: 20,
            left: 10,
            child: Icon(Icons.change_history, color: Colors.orange.withValues(alpha: 0.2), size: 10),
          ),
          Positioned(
            bottom: 40,
            right: 10,
            child: Icon(Icons.square_foot, color: Colors.pink.withValues(alpha: 0.2), size: 12),
          ),

          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Circle
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: lightColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      border: Border.all(color: color, width: 2.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSuccess ? Icons.check : Icons.close,
                      color: color,
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Color(0xFF2D3436),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: onButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
