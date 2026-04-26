import 'package:flutter/material.dart';

enum TicketStatus { open, inProgress, resolved }

enum LogLevel { info, warning, critical }

class SupportTicket {
  final String id;
  final String userId;
  final String userName;
  final String subject;
  final String message;
  final TicketStatus status;
  final DateTime createdAt;

  SupportTicket({
    required this.id,
    required this.userId,
    required this.userName,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  Color get statusColor {
    switch (status) {
      case TicketStatus.open:
        return Colors.orange;
      case TicketStatus.inProgress:
        return Colors.blue;
      case TicketStatus.resolved:
        return Colors.green;
    }
  }
}

class SystemLog {
  final String id;
  final String adminId;
  final String action; // e.g., "Blocked User", "Approved Service"
  final String details;
  final LogLevel level;
  final DateTime timestamp;

  SystemLog({
    required this.id,
    required this.adminId,
    required this.action,
    required this.details,
    required this.level,
    required this.timestamp,
  });
}

class AdminTransaction {
  final String id;
  final String providerId;
  final double amount;
  final double commission;
  final DateTime date;

  AdminTransaction({
    required this.id,
    required this.providerId,
    required this.amount,
    required this.commission,
    required this.date,
  });
}
