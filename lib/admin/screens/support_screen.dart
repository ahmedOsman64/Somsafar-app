import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/services/support_repository.dart';

class AdminSupportScreen extends ConsumerStatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  ConsumerState<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends ConsumerState<AdminSupportScreen> {
  String _filterStatus = 'All';
  String _filterType = 'All';

  @override
  Widget build(BuildContext context) {
    final allTickets = ref.watch(supportProvider);

    final filtered = allTickets.where((t) {
      final statusMatch =
          _filterStatus == 'All' ||
          (_filterStatus == 'Open' && t.status == TicketStatus.open) ||
          (_filterStatus == 'In Progress' &&
              t.status == TicketStatus.inProgress) ||
          (_filterStatus == 'Closed' && t.status == TicketStatus.closed);

      final typeMatch =
          _filterType == 'All' ||
          (_filterType == 'Support' && t.type == TicketType.contactSupport) ||
          (_filterType == 'Report' && t.type == TicketType.reportIssue) ||
          (_filterType == 'Chat' && t.type == TicketType.liveChat) ||
          (_filterType == 'FAQ' && t.type == TicketType.faq);

      return statusMatch && typeMatch;
    }).toList();

    final openCount = allTickets
        .where((t) => t.status == TicketStatus.open)
        .length;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: const BoxDecoration(color: Color(0xFF0A3D62)),
            child: Row(
              children: [
                const Icon(Icons.support_agent, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Support Tickets',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (openCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$openCount Open',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Filter Bar ─────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Open', 'In Progress', 'Closed'].map((
                      status,
                    ) {
                      final isSelected = _filterStatus == status;
                      final color = status == 'Open'
                          ? Colors.red
                          : status == 'In Progress'
                          ? Colors.orange
                          : status == 'Closed'
                          ? Colors.green
                          : const Color(0xFF0A3D62);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            status,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black87,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) =>
                              setState(() => _filterStatus = status),
                          selectedColor: color,
                          backgroundColor: Colors.grey.shade100,
                          showCheckmark: false,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 6),
                // Type filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Support', 'Report', 'Chat', 'FAQ'].map((
                      type,
                    ) {
                      final isSelected = _filterType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            type,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.black54,
                              fontSize: 11,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _filterType = type),
                          selectedColor: Colors.blueGrey.shade700,
                          backgroundColor: Colors.grey.shade100,
                          showCheckmark: false,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Ticket List ────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 60,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No tickets found',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Users will show up here when they submit support requests',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _TicketCard(ticket: filtered[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual Ticket Card
// ─────────────────────────────────────────────────────────────────────────────
class _TicketCard extends ConsumerWidget {
  final SupportTicket ticket;
  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch provider for live updates
    final liveTicket = ref
        .watch(supportProvider)
        .firstWhere((t) => t.id == ticket.id, orElse: () => ticket);

    final statusColor = liveTicket.status == TicketStatus.open
        ? Colors.red
        : liveTicket.status == TicketStatus.inProgress
        ? Colors.orange
        : Colors.green;
    final statusLabel = liveTicket.status == TicketStatus.open
        ? 'Open'
        : liveTicket.status == TicketStatus.inProgress
        ? 'In Progress'
        : 'Closed';
    final priorityColor = liveTicket.priority == TicketPriority.high
        ? Colors.red
        : liveTicket.priority == TicketPriority.medium
        ? Colors.orange
        : Colors.blue;
    final priorityLabel = liveTicket.priority == TicketPriority.high
        ? 'High'
        : liveTicket.priority == TicketPriority.medium
        ? 'Medium'
        : 'Low';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        childrenPadding: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: liveTicket.typeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(liveTicket.icon, color: liveTicket.typeColor, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                liveTicket.subject,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF0A3D62),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _buildPriorityBadge(priorityLabel, priorityColor),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'ID: ${liveTicket.id.substring(0, 8)} • ${liveTicket.userName}',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              _buildStatusBadge(statusLabel, statusColor),
            ],
          ),
        ),
        children: [_TicketDetail(ticket: liveTicket)],
      ),
    );
  }

  Widget _buildPriorityBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ticket Detail (thread + reply box)
// ─────────────────────────────────────────────────────────────────────────────
class _TicketDetail extends ConsumerStatefulWidget {
  final SupportTicket ticket;
  const _TicketDetail({required this.ticket});

  @override
  ConsumerState<_TicketDetail> createState() => _TicketDetailState();
}

class _TicketDetailState extends ConsumerState<_TicketDetail> {
  final _replyCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    await Future.delayed(const Duration(milliseconds: 400));
    ref.read(supportProvider.notifier).adminReply(widget.ticket.id, text);
    _replyCtrl.clear();
    setState(() => _sending = false);
  }

  void _changeStatus(TicketStatus status) {
    ref.read(supportProvider.notifier).updateStatus(widget.ticket.id, status);
  }

  @override
  Widget build(BuildContext context) {
    final liveTicket = ref
        .watch(supportProvider)
        .firstWhere(
          (t) => t.id == widget.ticket.id,
          orElse: () => widget.ticket,
        );

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),

          // ── Status control bar ────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  'Set Status:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                ...[
                  TicketStatus.open,
                  TicketStatus.inProgress,
                  TicketStatus.closed,
                ].map((s) {
                  final labels = {
                    TicketStatus.open: 'Open',
                    TicketStatus.inProgress: 'In Progress',
                    TicketStatus.closed: 'Closed',
                  };
                  final colors = {
                    TicketStatus.open: Colors.red,
                    TicketStatus.inProgress: Colors.orange,
                    TicketStatus.closed: Colors.green,
                  };
                  final isActive = liveTicket.status == s;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => _changeStatus(s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? colors[s]!.withValues(alpha: 0.15)
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive ? colors[s]! : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          labels[s]!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isActive ? colors[s] : Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Message thread ────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conversation',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                ...liveTicket.messages.map((msg) {
                  final isAdmin = msg.isAdmin;
                  return Align(
                    alignment: isAdmin
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.6,
                      ),
                      decoration: BoxDecoration(
                        color: isAdmin
                            ? const Color(0xFF0A3D62).withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(14),
                          topRight: const Radius.circular(14),
                          bottomLeft: Radius.circular(isAdmin ? 14 : 0),
                          bottomRight: Radius.circular(isAdmin ? 0 : 14),
                        ),
                        border: Border.all(
                          color: isAdmin
                              ? const Color(0xFF0A3D62).withValues(alpha: 0.2)
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isAdmin ? Icons.support_agent : Icons.person,
                                size: 12,
                                color: isAdmin
                                    ? const Color(0xFF0A3D62)
                                    : Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isAdmin ? 'Admin' : liveTicket.userName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isAdmin
                                      ? const Color(0xFF0A3D62)
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(msg.text, style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          // ── Admin reply box ───────────────────────────────
          if (liveTicket.status != TicketStatus.closed)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyCtrl,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Type your reply...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sending ? null : _sendReply,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _sending
                            ? Colors.grey.shade300
                            : const Color(0xFF0A3D62),
                        shape: BoxShape.circle,
                      ),
                      child: _sending
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'This ticket is closed.',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
