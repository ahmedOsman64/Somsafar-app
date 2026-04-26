import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/supabase_service.dart';
import '../models/user_model.dart';
import 'auth_service.dart';

// ─────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────
enum TicketType { contactSupport, reportIssue, liveChat, faq }

enum TicketStatus { open, inProgress, closed }

enum TicketPriority { low, medium, high }

// ─────────────────────────────────────────────
// SupportMessage
// ─────────────────────────────────────────────
class SupportMessage {
  final String id;
  final String text;
  final bool isAdmin;
  final DateTime timestamp;

  SupportMessage({
    required this.id,
    required this.text,
    required this.isAdmin,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isAdmin': isAdmin,
    'timestamp': timestamp.toIso8601String(),
  };

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'],
      text: json['text'],
      isAdmin: json['isAdmin'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

// ─────────────────────────────────────────────
// SupportTicket
// ─────────────────────────────────────────────
class SupportTicket {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final TicketType type;
  TicketStatus status;
  TicketPriority priority;
  final DateTime createdAt;
  final List<SupportMessage> messages;

  SupportTicket({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.type,
    this.status = TicketStatus.open,
    this.priority = TicketPriority.medium,
    required this.createdAt,
    required this.messages,
  });

  String get subject {
    switch (type) {
      case TicketType.contactSupport:
        return 'Contact Support';
      case TicketType.reportIssue:
        return 'Bug Report';
      case TicketType.liveChat:
        return 'Live Chat';
      case TicketType.faq:
        return 'FAQ Query';
    }
  }

  IconData get icon {
    switch (type) {
      case TicketType.contactSupport:
        return Icons.headset_mic_outlined;
      case TicketType.reportIssue:
        return Icons.report_problem_outlined;
      case TicketType.liveChat:
        return Icons.chat_bubble_outline;
      case TicketType.faq:
        return Icons.help_outline;
    }
  }

  Color get typeColor {
    switch (type) {
      case TicketType.contactSupport:
        return Colors.blue;
      case TicketType.reportIssue:
        return Colors.red;
      case TicketType.liveChat:
        return Colors.green;
      case TicketType.faq:
        return Colors.purple;
    }
  }

  String get preview => messages.isEmpty ? '' : messages.last.text;
  bool get hasAdminReply => messages.any((m) => m.isAdmin);
}

// ─────────────────────────────────────────────
// Repository
// ─────────────────────────────────────────────
class SupportRepository extends StateNotifier<List<SupportTicket>> {
  final Ref _ref;
  StreamSubscription? _subscription;

  SupportRepository(this._ref) : super([]) {
    _listenToAuth();
  }

  void _listenToAuth() {
    _ref.listen<User?>(authProvider, (previous, next) {
      if (next == null) {
        _subscription?.cancel();
        _subscription = null;
        state = [];
      } else if (previous?.id != next.id) {
        _initStream();
      }
    }, fireImmediately: true);
  }

  void _initStream() {
    _subscription?.cancel();
    _subscription = SupabaseConfig.client
        .from('support_tickets')
        .stream(primaryKey: ['id'])
        .listen((data) {
          if (!mounted) return;
          state = data.map((res) {
            // Parse messages jsonb array
            List<SupportMessage> msgs = [];
            if (res['messages'] != null) {
              msgs = (res['messages'] as List)
                  .map((m) => SupportMessage.fromJson(m))
                  .toList();
            }

            return SupportTicket(
              id: res['id'],
              userId: res['user_id'],
              userName: res['user_name'],
              userEmail: res['user_email'],
              type: TicketType.values.firstWhere(
                (e) => e.name == res['issue_type'],
                orElse: () => TicketType.contactSupport,
              ),
              status: TicketStatus.values.firstWhere(
                (e) => e.name == res['status'],
                orElse: () => TicketStatus.open,
              ),
              priority: TicketPriority.values.firstWhere(
                (e) => e.name == res['priority'],
                orElse: () => TicketPriority.medium,
              ),
              createdAt: DateTime.parse(res['created_at']),
              messages: msgs,
            );
          }).toList();
        }, onError: (error) {
          debugPrint('SupportRepository Stream error: $error');
        });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> createTicket({
    required String userId,
    required String userName,
    required String userEmail,
    required TicketType type,
    required String message,
    TicketPriority priority = TicketPriority.medium,
  }) async {
    final ticketId = const Uuid().v4();
    final firstMsg = SupportMessage(
      id: const Uuid().v4(),
      text: message,
      isAdmin: false,
      timestamp: DateTime.now(),
    );

    try {
      await SupabaseConfig.client.from('support_tickets').insert({
        'id': ticketId,
        'user_id': userId,
        'user_name': userName,
        'user_email': userEmail,
        'issue_type': type.name,
        'description': message, // initial description
        'status': TicketStatus.open.name,
        'priority': priority.name,
        'messages': [firstMsg.toJson()],
      });
    } catch (e) {
      debugPrint('Create ticket error: $e');
    }
  }

  Future<void> adminReply(String ticketId, String replyText) async {
    final ticket = state.firstWhere((t) => t.id == ticketId);
    final newMsg = SupportMessage(
      id: const Uuid().v4(),
      text: replyText,
      isAdmin: true,
      timestamp: DateTime.now(),
    );

    final updatedMessages = [
      ...ticket.messages,
      newMsg,
    ].map((m) => m.toJson()).toList();

    try {
      await SupabaseConfig.client
          .from('support_tickets')
          .update({
            'status': TicketStatus.inProgress.name,
            'messages': updatedMessages,
          })
          .eq('id', ticketId);
    } catch (e) {
      debugPrint('Admin reply error: $e');
    }
  }

  Future<void> updateStatus(String ticketId, TicketStatus newStatus) async {
    try {
      await SupabaseConfig.client
          .from('support_tickets')
          .update({'status': newStatus.name})
          .eq('id', ticketId);
    } catch (e) {
      debugPrint('Update ticket status error: $e');
    }
  }

  List<SupportTicket> ticketsForUser(String userId) {
    return state.where((t) => t.userId == userId).toList();
  }
}

final supportProvider =
    StateNotifierProvider<SupportRepository, List<SupportTicket>>((ref) {
  return SupportRepository(ref);
});
