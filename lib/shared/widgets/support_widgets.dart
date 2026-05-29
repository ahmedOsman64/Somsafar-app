import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/support_repository.dart';

class SupportSection extends ConsumerWidget {
  const SupportSection({super.key});

  void _openTicketDialog(BuildContext context, WidgetRef ref, TicketType type) {
    showDialog(
      context: context,
      builder: (_) => SubmitTicketDialog(ref: ref, type: type),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final myTickets = ref
        .watch(supportProvider)
        .where((t) => t.userId == (user?.id ?? ''))
        .toList();
    final hasReplies = myTickets.any((t) => t.hasAdminReply);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSupportItem(
          context,
          Icons.headset_mic_outlined,
          'Contact Support',
          'Get help from our team',
          Colors.blue,
          () => _openTicketDialog(context, ref, TicketType.contactSupport),
        ),
        _buildSupportItem(
          context,
          Icons.report_problem_outlined,
          'Report an Issue',
          'Found a bug? Let us know',
          Colors.red,
          () => _openTicketDialog(context, ref, TicketType.reportIssue),
        ),
        _buildSupportItem(
          context,
          Icons.help_outline,
          'FAQs',
          'Frequently asked questions',
          Colors.purple,
          () {
            showDialog(
              context: context,
              builder: (context) => const FAQDialog(),
            );
          },
        ),
        _buildSupportItem(
          context,
          Icons.chat_bubble_outline,
          'Live Chat',
          'Chat with us now',
          Colors.green,
          () {
            showDialog(
              context: context,
              builder: (context) => LiveChatDialog(ref: ref),
            );
          },
        ),
        if (myTickets.isNotEmpty) ...[
          const Divider(height: 32),
          Row(
            children: [
              const Text(
                'My Tickets',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              if (hasReplies) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    'Admin replied',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ...myTickets.map((t) => _buildMyTicketCard(context, ref, t)),
        ],
      ],
    );
  }

  Widget _buildMyTicketCard(
    BuildContext context,
    WidgetRef ref,
    SupportTicket ticket,
  ) {
    final statusColor = ticket.status == TicketStatus.open
        ? Colors.red
        : ticket.status == TicketStatus.inProgress
        ? Colors.orange
        : Colors.green;
    final statusLabel = ticket.status == TicketStatus.open
        ? 'Open'
        : ticket.status == TicketStatus.inProgress
        ? 'In Progress'
        : 'Closed';

    return InkWell(
      onTap: () => showDialog(
        context: context,
        builder: (_) => TicketThreadDialog(ref: ref, ticket: ticket),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ticket.typeColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(ticket.icon, color: ticket.typeColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${ticket.id.substring(0, 8)}... • ${ticket.subject}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ticket.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (ticket.hasAdminReply)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.mark_chat_read,
                      size: 14,
                      color: Colors.green.shade600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Colors.grey,
      ),
      onTap: onTap,
    );
  }
}

class FAQDialog extends StatefulWidget {
  const FAQDialog({super.key});

  @override
  State<FAQDialog> createState() => _FAQDialogState();
}

class _FAQDialogState extends State<FAQDialog> {
  final List<Map<String, String>> _faqs = [
    {
      'question': 'How do I book a trip?',
      'answer': 'You can book a trip by searching for your destination on the home screen, selecting a travel package, and clicking "Book Now". Follow the prompts to complete your booking.'
    },
    {
      'question': 'What payment methods are supported?',
      'answer': 'We support major mobile money services (EVC Plus, Sahal, Premier Wallet) and credit/debit cards for secure payments.'
    },
    {
      'question': 'Can I cancel my booking?',
      'answer': 'Yes, you can cancel your booking from the "My Bookings" section. Please note that cancellation policies vary by trip and operator.'
    },
    {
      'question': 'How do I contact my driver or guide?',
      'answer': 'Once your booking is confirmed, you will receive the contact details of your driver or guide in the booking details screen.'
    },
    {
      'question': 'How do I verify my profile?',
      'answer': 'To verify your profile, go to your profile settings and complete all the required fields, including uploading a profile picture and verifying your phone number.'
    },
  ];

  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredFaqs = _faqs.where((faq) {
      return faq['question']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          faq['answer']!.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.help_outline, color: Colors.purple, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('FAQs', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search for questions...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredFaqs.length,
                itemBuilder: (context, index) {
                  return ExpansionTile(
                    title: Text(
                      filteredFaqs[index]['question']!,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(
                          filteredFaqs[index]['answer']!,
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class LiveChatDialog extends StatefulWidget {
  final WidgetRef ref;
  const LiveChatDialog({super.key, required this.ref});

  @override
  State<LiveChatDialog> createState() => _LiveChatDialogState();
}

class _LiveChatDialogState extends State<LiveChatDialog> {
  final _msgCtrl = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {
      'text': 'Hi! How can we help you today?',
      'isMe': false,
      'time': DateTime.now(),
    },
  ];
  bool _isTyping = false;

  void _sendMessage() {
    if (_msgCtrl.text.trim().isEmpty) return;

    final text = _msgCtrl.text.trim();
    setState(() {
      _messages.add({'text': text, 'isMe': true, 'time': DateTime.now()});
      _msgCtrl.clear();
      _isTyping = true;
    });

    final user = widget.ref.read(authProvider);
    widget.ref.read(supportProvider.notifier).createTicket(
      userId: user?.id ?? 'guest',
      userName: user?.name ?? 'Guest',
      userEmail: user?.email ?? '',
      type: TicketType.liveChat,
      message: text,
      priority: TicketPriority.medium,
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add({
            'text': 'Thanks for your message! Our team has been notified and will get back to you shortly in your "My Tickets" section.',
            'isMe': false,
            'time': DateTime.now(),
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
            SizedBox(width: 12),
            Text(
              'Live Chat',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isMe = msg['isMe'] as bool;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.green.shade100 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(msg['text']),
                    ),
                  );
                },
              ),
            ),
            if (_isTyping)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Support is typing...', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
                ),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Colors.green),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SubmitTicketDialog extends StatefulWidget {
  final WidgetRef ref;
  final TicketType type;
  const SubmitTicketDialog({super.key, required this.ref, required this.type});

  @override
  State<SubmitTicketDialog> createState() => _SubmitTicketDialogState();
}

class _SubmitTicketDialogState extends State<SubmitTicketDialog> {
  final _formKey = GlobalKey<FormState>();
  final _msgCtrl = TextEditingController();
  TicketPriority _priority = TicketPriority.medium;
  bool _loading = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.type) {
      case TicketType.contactSupport:
        return 'Contact Support';
      case TicketType.reportIssue:
        return 'Report an Issue';
      case TicketType.liveChat:
        return 'Live Chat';
      case TicketType.faq:
        return 'FAQ Query';
    }
  }

  String get _hint {
    switch (widget.type) {
      case TicketType.contactSupport:
        return 'Describe how we can help you...';
      case TicketType.reportIssue:
        return 'Describe the bug or issue in detail...';
      case TicketType.liveChat:
        return 'Type your message to start a live chat...';
      case TicketType.faq:
        return 'What would you like to know?';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 500));

    final user = widget.ref.read(authProvider);
    widget.ref.read(supportProvider.notifier).createTicket(
      userId: user?.id ?? 'guest',
      userName: user?.name ?? user?.email ?? 'Guest',
      userEmail: user?.email ?? '',
      type: widget.type,
      message: _msgCtrl.text.trim(),
      priority: _priority,
    );

    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Ticket submitted! Admin will respond shortly.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.support_agent, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _msgCtrl,
                minLines: 4,
                maxLines: 6,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please write a message' : null,
                decoration: InputDecoration(
                  hintText: _hint,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Priority',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: TicketPriority.values.map((p) {
                  final labels = {
                    TicketPriority.low: 'Low',
                    TicketPriority.medium: 'Medium',
                    TicketPriority.high: 'High',
                  };
                  final colors = {
                    TicketPriority.low: Colors.blue,
                    TicketPriority.medium: Colors.orange,
                    TicketPriority.high: Colors.red,
                  };
                  final isSelected = _priority == p;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _priority = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? colors[p]!.withValues(alpha: 0.15) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? colors[p]! : Colors.grey.shade300,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            labels[p]!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? colors[p] : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Submit Ticket'),
        ),
      ],
    );
  }
}

class TicketThreadDialog extends StatelessWidget {
  final WidgetRef ref;
  final SupportTicket ticket;
  const TicketThreadDialog({super.key, required this.ref, required this.ticket});

  @override
  Widget build(BuildContext context) {
    final liveTicket = ref
        .watch(supportProvider)
        .firstWhere((t) => t.id == ticket.id, orElse: () => ticket);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      title: Row(
        children: [
          Icon(liveTicket.icon, color: liveTicket.typeColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  liveTicket.subject,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  liveTicket.id.substring(0, 8),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        height: 320,
        child: ListView(
          children: liveTicket.messages.map((msg) {
            final isAdmin = msg.isAdmin;
            return Align(
              alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: const BoxConstraints(maxWidth: 300),
                decoration: BoxDecoration(
                  color: isAdmin ? Colors.blue.shade50 : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(14),
                    topRight: const Radius.circular(14),
                    bottomLeft: Radius.circular(isAdmin ? 0 : 14),
                    bottomRight: Radius.circular(isAdmin ? 14 : 0),
                  ),
                  border: Border.all(
                    color: isAdmin ? Colors.blue.shade100 : AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(Icons.support_agent, size: 12, color: Colors.blue.shade700),
                            const SizedBox(width: 4),
                            Text(
                              'Support Team',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(msg.text, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
