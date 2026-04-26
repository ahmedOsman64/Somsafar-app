import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import 'user_repository.dart';
import 'auth_service.dart';

/// Provider that returns only the helpers belonging to the currently logged-in provider.
final helpersProvider = Provider<List<User>>((ref) {
  final currentUser = ref.watch(authProvider);
  final allUsers = ref.watch(userProvider);

  if (currentUser == null) return [];

  // Filter for users who are provider_helpers AND belong to THIS provider
  return allUsers.where((u) {
    return u.role == UserRole.providerHelper && 
           u.providerId == currentUser.id;
  }).toList();
});

/// Provider for the total count of helpers (for easy display like "1/3")
final helperCountProvider = Provider<int>((ref) {
  return ref.watch(helpersProvider).length;
});
