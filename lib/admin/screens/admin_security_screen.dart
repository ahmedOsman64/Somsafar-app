import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/system_activity_repository.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/services/user_repository.dart';
import '../../shared/models/user_model.dart';
import 'package:intl/intl.dart';

class AdminSecurityScreen extends ConsumerWidget {
  const AdminSecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(adminActivityProvider);
    final securityLogs = activities.where((a) => 
      a.type == ActivityType.security || 
      a.type == ActivityType.securityAlert ||
      a.type == ActivityType.userDeletion ||
      a.type == ActivityType.statusUpdate
    ).toList();
    
    final blockedUsers = ref.watch(userProvider).where((u) => u.status == UserStatus.blocked).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const Text(
                  'Security Command Center',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const Text(
                  'Monitor platform integrity and trigger emergency actions',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 32),
                
                // Emergency Actions Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.redAccent, Colors.red],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withAlpha(51),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.gpp_maybe, color: Colors.white, size: 32),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Emergency Actions',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _SecurityActionButton(
                            icon: Icons.notifications_active,
                            label: 'Broadcast Alert',
                            onTap: () => _showBroadcastDialog(context, ref),
                          ),
                          _SecurityActionButton(
                            icon: Icons.shield,
                            label: 'High Alert',
                            onTap: () => _triggerHighAlert(context, ref),
                          ),
                          _SecurityActionButton(
                            icon: Icons.lock_person,
                            label: 'Lock Operations',
                            onTap: () => _simulateLockdown(context, ref),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
              ]),
            ),
          ),

          // Blocked Users Section
          if (blockedUsers.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lock_clock, color: Colors.red),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Blocked Accounts',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: blockedUsers.length,
                        separatorBuilder: (c, i) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final user = blockedUsers[index];
                          return Container(
                            key: ValueKey('blocked_${user.id}'),
                            width: 250,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withAlpha(51)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.red.withAlpha(26),
                                  child: const Icon(Icons.person, color: Colors.red),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        user.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        user.email,
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _showUnblockDialog(context, ref, user),
                                  icon: const Icon(Icons.lock_open, color: Colors.green),
                                  tooltip: 'Unblock',
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
          
          // Security Logs Header
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Recent Security Events',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => ref.read(activityProvider.notifier).fetchActivities(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          
          // Security Logs List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: securityLogs.isEmpty
              ? SliverToBoxAdapter(child: _buildEmptyLogs())
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final log = securityLogs[index];
                      return Card(
                        key: ValueKey('log_${log.id}'),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: log.iconColor.withAlpha(30),
                            child: Icon(log.icon, color: log.iconColor, size: 20),
                          ),
                          title: Text(
                            log.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            log.subtitle,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                          trailing: Text(
                            DateFormat('HH:mm\nMMM d').format(log.timestamp),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ),
                      );
                    },
                    childCount: securityLogs.length,
                  ),
                ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildEmptyLogs() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Icon(Icons.verified_user_outlined, size: 64, color: Colors.green.withAlpha(100)),
            const SizedBox(height: 16),
            const Text('No critical security events detected.'),
          ],
        ),
      ),
    );
  }

  void _showBroadcastDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Broadcast Security Notice'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter alert message...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final admin = ref.read(authProvider);
                ref.read(activityProvider.notifier).logSecurityAlert(
                  title: 'Security Broadcast',
                  message: controller.text,
                  adminId: admin?.id,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Security alert broadcasted and logged.')),
                );
              }
            },
            child: const Text('Broadcast'),
          ),
        ],
      ),
    );
  }

  void _triggerHighAlert(BuildContext context, WidgetRef ref) {
    final admin = ref.read(authProvider);
    ref.read(activityProvider.notifier).logSecurityAlert(
      title: 'SYSTEM HIGH ALERT',
      message: 'Platform-wide high alert triggered by admin.',
      adminId: admin?.id,
      isHighPriority: true,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SYSTEM HIGH ALERT ACTIVATED'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _simulateLockdown(BuildContext context, WidgetRef ref) {
    final admin = ref.read(authProvider);
    ref.read(activityProvider.notifier).logSecurityAlert(
      title: 'Operations Locked',
      message: 'Sensitive operations have been temporarily suspended for security.',
      adminId: admin?.id,
      isHighPriority: true,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Operation lockdown logged.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showUnblockDialog(BuildContext context, WidgetRef ref, User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock User'),
        content: Text('Are you sure you want to unblock ${user.name}? This will reset their failed login attempts.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(userProvider.notifier).updateUser(user.copyWith(status: UserStatus.active));
              if (context.mounted) Navigator.pop(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${user.name} has been unblocked.')),
                );
              }
            },
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
  }
}

class _SecurityActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SecurityActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.red,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }
}
