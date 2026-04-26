import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/user_model.dart';
import '../../shared/services/user_repository.dart';
import '../../core/theme/app_colors.dart';

class AdminHelpersScreen extends ConsumerStatefulWidget {
  const AdminHelpersScreen({super.key});

  @override
  ConsumerState<AdminHelpersScreen> createState() => _AdminHelpersScreenState();
}

class _AdminHelpersScreenState extends ConsumerState<AdminHelpersScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final allUsers = ref.watch(userProvider);
    
    // Filter for helpers
    final helpers = allUsers.where((u) => u.role == UserRole.providerHelper).toList();
    
    // Group helpers by providerId
    final Map<String, List<User>> groupedHelpers = {};
    for (var helper in helpers) {
      final pid = helper.providerId ?? 'unknown';
      if (!groupedHelpers.containsKey(pid)) {
        groupedHelpers[pid] = [];
      }
      groupedHelpers[pid]!.add(helper);
    }

    // Filter by search
    final sortedProviderIds = groupedHelpers.keys.toList();
    final providers = allUsers.where((u) => u.role == UserRole.provider).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search helpers...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: sortedProviderIds.length,
                itemBuilder: (context, index) {
                  final providerId = sortedProviderIds[index];
                  final providerHelpers = groupedHelpers[providerId]!;
                  final provider = providers.firstWhere(
                    (p) => p.id == providerId,
                    orElse: () => User(
                      id: providerId,
                      name: 'Unknown Provider',
                      email: '',
                      password: '',
                      role: UserRole.provider,
                    ),
                  );

                  // Filter helpers in this group by search query
                  final filteredHelpers = providerHelpers.where((h) {
                    final q = _searchQuery.toLowerCase();
                    return h.name.toLowerCase().contains(q) || 
                           h.email.toLowerCase().contains(q);
                  }).toList();

                  if (filteredHelpers.isEmpty && _searchQuery.isNotEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.store, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Provider: ${provider.name}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D3B66),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${filteredHelpers.length} Helpers',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.withAlpha(30)),
                        ),
                        child: Column(
                          children: filteredHelpers.map((helper) {
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFF1F5F9),
                                child: Text(
                                  helper.name.isNotEmpty
                                      ? helper.name.substring(0, 1).toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D3B66),
                                  ),
                                ),
                              ),
                              title: Text(
                                helper.name,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(helper.email, style: TextStyle(color: Colors.grey[600])),
                                  if (helper.metadata.containsKey('helper_role'))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6.0),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withAlpha(30),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              helper.metadata['helper_role'].toString().toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Rules: ${(helper.metadata['permissions'] as List?)?.join(', ') ?? 'None'}',
                                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              isThreeLine: helper.metadata.containsKey('helper_role'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: helper.status == UserStatus.active 
                                          ? Colors.green.withAlpha(26) 
                                          : Colors.red.withAlpha(26),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      helper.status.name.toUpperCase(),
                                      style: TextStyle(
                                        color: helper.status == UserStatus.active 
                                            ? Colors.green 
                                            : Colors.red,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
