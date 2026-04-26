import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/system_activity_repository.dart';

class AdminLogsScreen extends ConsumerWidget {
  const AdminLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(adminActivityProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Audit Logs'),
        backgroundColor: AppColors.dark,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(activityProvider.notifier).fetchActivities(),
            tooltip: 'Refresh Logs',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {},
            tooltip: 'Export Logs',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterHeader(),
          Expanded(
            child: logs.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(activityProvider.notifier).fetchActivities(),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        return ListTile(
                          leading: _getLogIcon(log),
                          title: Text(
                            log.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(log.subtitle),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    DateFormat(
                                      'yyyy-MM-dd HH:mm:ss',
                                    ).format(log.timestamp),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '•',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    log.role?.name ?? 'System',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No audit logs found',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search logs...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
        ],
      ),
    );
  }

  Widget _getLogIcon(SystemActivity log) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: log.iconColor.withAlpha(26),
        shape: BoxShape.circle,
      ),
      child: Icon(log.icon, color: log.iconColor, size: 20),
    );
  }
}
