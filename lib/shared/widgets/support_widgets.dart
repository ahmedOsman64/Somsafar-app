import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/auth_service.dart';
import '../../core/providers/localization_provider.dart';
import 'package:go_router/go_router.dart';
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
    final loc = ref.watch(localizationProvider);
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
          loc.translate('contact_support'),
          loc.translate('get_help'),
          Colors.blue,
          () => _openTicketDialog(context, ref, TicketType.contactSupport),
        ),
        _buildSupportItem(
          context,
          Icons.report_problem_outlined,
          loc.translate('report_issue'),
          loc.translate('found_bug'),
          Colors.red,
          () => _openTicketDialog(context, ref, TicketType.reportIssue),
        ),
        _buildSupportItem(
          context,
          Icons.help_outline,
          loc.translate('faqs'),
          loc.translate('freq_asked_questions'),
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
          loc.translate('live_chat'),
          loc.translate('chat_now'),
          Colors.green,
          () {
            showDialog(
              context: context,
              builder: (context) => const LiveChatDialog(),
            );
          },
        ),
        _buildSupportItem(
          context,
          Icons.info_outline,
          loc.translate('about_somsafar'),
          loc.translate('learn_more'),
          Colors.orange,
          () {
            showDialog(
              context: context,
              builder: (context) => const AboutSomSafarDialog(),
            );
          },
        ),
        _buildSupportItem(
          context,
          Icons.privacy_tip_outlined,
          loc.translate('privacy_policy'),
          loc.translate('how_handle_data'),
          Colors.teal,
          () {
            showDialog(
              context: context,
              builder: (context) => const PrivacyPolicyDialog(),
            );
          },
        ),
        if (myTickets.isNotEmpty) ...[
          const Divider(height: 32),
          Row(
            children: [
              Text(
                loc.translate('my_tickets'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                    loc.translate('admin_replied'),
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
    final loc = ref.read(localizationProvider);
    final statusColor = ticket.status == TicketStatus.open
        ? Colors.red
        : ticket.status == TicketStatus.inProgress
        ? Colors.orange
        : Colors.green;
    final statusLabel = ticket.status == TicketStatus.open
        ? loc.translate('ticket_open')
        : ticket.status == TicketStatus.inProgress
        ? loc.translate('ticket_in_progress')
        : loc.translate('ticket_closed');

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

class FAQDialog extends ConsumerStatefulWidget {
  const FAQDialog({super.key});

  @override
  ConsumerState<FAQDialog> createState() => _FAQDialogState();
}

class _FAQDialogState extends ConsumerState<FAQDialog> {
  List<Map<String, String>> _getFaqs(String langCode) {
    if (langCode == 'so') {
      return [
        {
          'question': 'Sideen u ballansadaa safar?',
          'answer': 'Waxaad ballansan kartaa safar adiga oo ka raadinaya meesha aad u socoto bogga hore, dooranaya xirmo safar, ka dibna gujinaya "Hadda Ballanso". Raac tilmaamaha si aad u dhammaystirto ballansashadaada.'
        },
        {
          'question': 'Waa maxay hababka lacag bixinta ee la taageero?',
          'answer': 'Waxaan taageernaa adeegyada lacagta moobilka ee ugu waaweyn (EVC Plus, Sahal, Premier Wallet) iyo kaararka deynta/debit-ka ee lacag bixinta badbaadsan.'
        },
        {
          'question': 'Miyaan kansali karaa ballanteyda?',
          'answer': 'Haa, waxaad kaga kansali kartaa ballantaada qaybta "My Bookings". Fadlan ogow in shuruucda kansalaadu ay ku kala duwan yihiin safarka iyo adeeg bixiyaha.'
        },
        {
          'question': 'Sideen ula xiriiraa darawalkeyga ama hagahayga?',
          'answer': 'Marka ballantaada la xaqiijiyo, waxaad heli doontaa faahfaahinta xiriirka darawalkaaga ama hagahaaga oo ku taal bogga faahfaahinta booska.'
        },
        {
          'question': 'Sideen u xaqiijiyaa profile-kayga?',
          'answer': 'Si aad u xaqiijiso profile-kaaga, tag settings-ka profile-kaaga oo buuxi dhammaan meelaha loo baahan yahay, oo ay ku jirto inaad geliso sawirka profile-ka oo aad xaqiijiso lambarkaaga telefoonka.'
        },
        {
          'question': 'Sidee u shaqeeyaan lacag celintu?',
          'answer': 'Lacag celinta waxaa dib loogu soo celiyaa habkii aad markii hore u bixisay (tusaale EVC Plus, Sahal, ama kaarka) muddo 2-3 maalmood oo shaqo ah ka dib marka kansalaada la ansixiyo.'
        },
        {
          'question': 'Maxaa dhacaya haddii adeeg bixiyuhu kansalo ballanteyda?',
          'answer': 'Haddii bixiyuhu kansalo booskaaga, waxaad heli doontaa lacag celin buuxda oo 100% ah isla markaaba, kooxdayada taageerada ayaa kaa caawin doonta inaad hesho bedel kale.'
        },
        {
          'question': 'Ma ammaan baa xogta lacag bixintaydu?',
          'answer': 'Haa. Waxaan isticmaalnaa hab-maamuusyada sirta ah ee heerka warshadaha iyo is-dhexgalka lacagta moobilka ee sugan si loo hubiyo in xogtaada iyo macaamilkaagu ay si buuxda u badباadsan yihiin.'
        },
        {
          'question': 'Miyaan bedeli karaa taariikhaha ballansashada?',
          'answer': 'Haa, waxaad codsan kartaa bedelka taariikhda adiga oo la xiriiraya kooxdayada taageerada macaamiisha ama adiga oo toos ula xiriiraya adeeg bixiyaha adigoo isticmaalaya app-ka.'
        },
      ];
    } else if (langCode == 'ar') {
      return [
        {
          'question': 'كيف يمكنني حجز رحلة؟',
          'answer': 'يمكنك حجز رحلة من خلال البحث عن وجهتك على الشاشة الرئيسية، واختيار باقة السفر، ثم النقر على "احجز الآن". اتبع التعليمات لإتمام الحجز.'
        },
        {
          'question': 'ما هي وسائل الدفع المدعومة؟',
          'answer': 'نحن ندعم خدمات الدفع عبر الهاتف المحمول الرئيسية (إي في سي بلس، سهل، بريمير والت) والبطاقات الائتمانية/الخصم للمدفوعات الآمنة.'
        },
        {
          'question': 'هل يمكنني إلغاء حجزي؟',
          'answer': 'نعم، يمكنك إلغاء حجزك من قسم "حجوزاتي". يرجى ملاحظة أن سياسات الإلغاء تختلف حسب الرحلة ومقدم الخدمة.'
        },
        {
          'question': 'كيف يمكنني الاتصال بالسائق أو المرشد؟',
          'answer': 'بمجرد تأكيد حجزك، ستتلقى تفاصيل الاتصال بالسائق أو المرشد في شاشة تفاصيل الحجز.'
        },
        {
          'question': 'كيف يمكنني تفعيل ملفي الشخصي؟',
          'answer': 'لتفعيل ملفك الشخصي، انتقل إلى إعدادات الملف الشخصي وأكمل جميع الحقول المطلوبة، بما في ذلك تحميل صورة للملف وتأكيد رقم هاتفك.'
        },
        {
          'question': 'كيف تعمل عملية استرداد الأموال؟',
          'answer': 'يتم استرداد الأموال إلى وسيلة الدفع الأصلية (مثل إي في سي بلس، سهل، أو البطاقة) خلال 2-3 أيام عمل بعد الموافقة على إلغاء الحجز.'
        },
        {
          'question': 'ماذا يحدث إذا ألغى مقدم الخدمة حجزي؟',
          'answer': 'إذا ألغى المزود حجزك، فستتلقى استرداداً كاملاً بنسبة 100% فوراً، وسيقوم فريق الدعم بمساعدتك في العثور على بديل.'
        },
        {
          'question': 'هل بيانات الدفع الخاصة بي آمنة؟',
          'answer': 'نعم. نحن نستخدم بروتوكولات تشفير معيارية وتكاملات دفع آمنة عبر الهاتف لضمان حماية بياناتك ومعاملاتك بالكامل.'
        },
        {
          'question': 'هل يمكنني تغيير تواريخ الحجز؟',
          'answer': 'نعم، يمكنك طلب تعديل التواريخ عن طريق الاتصال بفريق دعم العملاء أو التواصل مع المزود مباشرة عبر التطبيق.'
        },
      ];
    }
    return [
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
      {
        'question': 'How do refunds work?',
        'answer': 'Refunds are processed back to your original payment method (e.g. EVC Plus, Sahal, or card) within 2-3 business days after a cancellation is approved.'
      },
      {
        'question': 'What if the operator cancels my booking?',
        'answer': 'If a provider cancels your booking, you will receive a full 100% refund immediately, and our support team will help you find an alternative.'
      },
      {
        'question': 'Is my payment data secure?',
        'answer': 'Yes. We use industry-standard encryption protocols and secure mobile money integrations to ensure your data and transactions are completely protected.'
      },
      {
        'question': 'Can I change my booking dates?',
        'answer': 'Yes, you can request date modifications by contacting our customer support team or by reaching out to the provider directly through the app.'
      },
    ];
  }

  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationProvider);
    final faqsList = _getFaqs(loc.languageCode);
    final filteredFaqs = faqsList.where((faq) {
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
          Text(loc.translate('faqs'), style: const TextStyle(fontWeight: FontWeight.bold)),
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
                hintText: loc.translate('search_questions'),
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
          child: Text(loc.translate('close')),
        ),
      ],
    );
  }
}

class LiveChatDialog extends ConsumerStatefulWidget {
  const LiveChatDialog({super.key});

  @override
  ConsumerState<LiveChatDialog> createState() => _LiveChatDialogState();
}

class _LiveChatDialogState extends ConsumerState<LiveChatDialog> {
  final _msgCtrl = TextEditingController();
  bool _isTyping = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_msgCtrl.text.trim().isEmpty) return;

    final text = _msgCtrl.text.trim();
    _msgCtrl.clear();

    final user = ref.read(authProvider);
    final tickets = ref.read(supportProvider);
    final userId = user?.id ?? 'guest';

    // Find any active live chat ticket
    SupportTicket? activeTicket;
    try {
      activeTicket = tickets.firstWhere(
        (t) => t.userId == userId && t.type == TicketType.liveChat && t.status != TicketStatus.closed,
      );
    } catch (_) {
      // Not found
    }

    if (activeTicket != null) {
      // Append to existing ticket
      ref.read(supportProvider.notifier).addMessage(activeTicket.id, text, isAdmin: false);
    } else {
      // Create a new ticket
      ref.read(supportProvider.notifier).createTicket(
        userId: userId,
        userName: user?.name ?? 'Guest',
        userEmail: user?.email ?? '',
        type: TicketType.liveChat,
        message: text,
        priority: TicketPriority.medium,
      );
    }

    // Simulate typing indicator for support agent
    setState(() => _isTyping = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isTyping = false);
        // Automatically append welcome reply to the ticket
        if (activeTicket != null) {
          ref.read(supportProvider.notifier).addMessage(
            activeTicket.id,
            'Thanks for your message! Our team has been notified and will get back to you shortly.',
            isAdmin: true,
          );
        } else {
          // If we just created the ticket, let's find it (or wait for stream) and reply
          final updatedTickets = ref.read(supportProvider);
          try {
            final newTicket = updatedTickets.firstWhere(
              (t) => t.userId == userId && t.type == TicketType.liveChat && t.status != TicketStatus.closed,
            );
            ref.read(supportProvider.notifier).addMessage(
              newTicket.id,
              'Thanks for your message! Our team has been notified and will get back to you shortly.',
              isAdmin: true,
            );
          } catch (_) {
            // Ignore if not loaded yet
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);

    if (user == null) {
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
        contentPadding: const EdgeInsets.all(24),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Fadlan soo gal si aad u bilowdo Live Chat',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Waxaad u baahan tahay akoon si aad ula xiriirto taageerada.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Soo Gal (Login)'),
              ),
            ],
          ),
        ),
      );
    }

    final tickets = ref.watch(supportProvider);
    final userId = user.id;

    // Find the active live chat ticket
    SupportTicket? activeTicket;
    try {
      activeTicket = tickets.firstWhere(
        (t) => t.userId == userId && t.type == TicketType.liveChat && t.status != TicketStatus.closed,
      );
    } catch (_) {
      // Not found
    }

    // Build list of messages to show
    final List<Map<String, dynamic>> displayMessages = [
      {
        'text': 'Hi! How can we help you today?',
        'isMe': false,
      },
    ];

    if (activeTicket != null) {
      for (final msg in activeTicket.messages) {
        displayMessages.add({
          'text': msg.text,
          'isMe': !msg.isAdmin,
        });
      }
    }

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
                itemCount: displayMessages.length,
                itemBuilder: (context, index) {
                  final msg = displayMessages[index];
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

class AboutSomSafarDialog extends StatelessWidget {
  const AboutSomSafarDialog({super.key});

  Widget _buildFeatureItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Image / Logo Card
              Container(
                padding: const EdgeInsets.only(top: 32, bottom: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: 60,
                      width: 60,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const Text(
                'SomSafar',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Somalia\'s Premier Travel Companion',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    Text(
                      'SomSafar is your ultimate travel guide and booking gateway, built to deliver a world-class travel experience across Somalia. Explore, book, and journey with ease, comfort, and absolute peace of mind.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Divider
                    Container(
                      height: 1,
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                    const SizedBox(height: 20),
                    // Features
                    _buildFeatureItem(
                      icon: Icons.verified_user_outlined,
                      iconColor: Colors.green,
                      title: 'Verified Partners',
                      desc: 'Fully vetted hotels, apartments, and tours.',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      icon: Icons.speed_outlined,
                      iconColor: Colors.blue,
                      title: 'Instant Bookings',
                      desc: 'Confirm your spot instantly with zero delays.',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(
                      icon: Icons.support_agent_outlined,
                      iconColor: Colors.orange,
                      title: '24/7 Local Support',
                      desc: 'We are here to assist you at every step of the way.',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              // Footer & Version
              Container(
                padding: const EdgeInsets.all(20),
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Version 1.0.0+4 from Zust',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PrivacyPolicyDialog extends StatelessWidget {
  const PrivacyPolicyDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.privacy_tip_outlined, color: Colors.teal, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: const SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Effective Date: June 13, 2026',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              SizedBox(height: 16),
              Text(
                '1. Data Collection',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                'We collect information you provide directly to us when you create an account, make a booking, or communicate with our support team.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                '2. Use of Information',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                'Your information is used to process bookings, provide support, and improve our services. We do not sell your personal data to third parties.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                '3. Security',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 4),
              Text(
                'We implement industry-standard security measures to protect your data from unauthorized access or disclosure.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                'For more detailed information, please visit our website at somsafar.com/privacy',
                style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('I Understand'),
        ),
      ],
    );
  }
}
