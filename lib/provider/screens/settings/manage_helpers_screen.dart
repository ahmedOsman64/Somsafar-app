import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/responsive.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/helpers_repository.dart';
import '../../../shared/services/user_repository.dart';
import '../../../shared/models/user_model.dart';
import '../../../shared/widgets/confirmation_dialog.dart';

class ManageHelpersScreen extends ConsumerStatefulWidget {
  const ManageHelpersScreen({super.key});

  @override
  ConsumerState<ManageHelpersScreen> createState() =>
      _ManageHelpersScreenState();
}

class _ManageHelpersScreenState extends ConsumerState<ManageHelpersScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final helpers = ref.watch(helpersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Full-Width Header Banner ────────────────────────
                _buildHeader(context, helpers.length),

                const SizedBox(height: 20),

                // ── Information & Permissions Card ────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildInfoCard(helpers.length),
                ),

                const SizedBox(height: 24),

                // ── Helper Cards / Empty State ──────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: helpers.isEmpty
                      ? _buildEmptyState(context)
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: helpers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) => _buildHelperCard(
                            context,
                            helpers[index],
                          ),
                        ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black38,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(context.isMobile ? 0 : 32),
          bottomRight: Radius.circular(context.isMobile ? 0 : 32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, context.isMobile ? 24 : 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.group_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manage Staff & Helpers',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Delegate booking & service handling access',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: count >= 3
                        ? null
                        : () => _showCreateHelperDialog(context),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text('Create Helper'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(int count) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Staff Helper Permissions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: count >= 3
                      ? Colors.orange.withAlpha(20)
                      : const Color(0xFF10B981).withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: count >= 3 ? Colors.orange : const Color(0xFF10B981),
                  ),
                ),
                child: Text(
                  '$count / 3 Slots Created',
                  style: TextStyle(
                    color: count >= 3 ? Colors.orange : const Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Helpers can view and manage your bookings, service listings, and customer reviews, but cannot view your financial earnings, payout accounts, or system settings.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey[600], height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.badge_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No staff helpers created yet',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create helper sub-accounts to delegate daily booking check-ins & service updates to your staff.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _showCreateHelperDialog(context),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Create First Helper'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelperCard(BuildContext context, User helper) {
    final role = helper.metadata['helper_role'] ?? 'Staff';
    final permissionsList =
        (helper.metadata['permissions'] as List?)?.join(', ') ?? 'Manage Bookings';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withAlpha(20),
            child: Text(
              helper.name.isNotEmpty ? helper.name[0].toUpperCase() : 'H',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      helper.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  helper.email,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded,
                        size: 13, color: const Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Permissions: $permissionsList',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: Colors.grey[500]),
            onSelected: (val) {
              if (val == 'view') {
                _showViewHelperDialog(context, helper);
              } else if (val == 'edit') {
                _showEditHelperDialog(context, helper);
              } else if (val == 'delete') {
                _removeHelper(context, helper.id);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'view',
                child: Text('View Details'),
              ),
              const PopupMenuItem(
                value: 'edit',
                child: Text('Edit Permissions'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Remove Helper',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreateHelperDialog(BuildContext context) {
    final fullNameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    String helperRole = 'Staff';
    final List<String> selectedPermissions = [
      'Manage Bookings',
      'Manage Services',
    ];
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create Helper Account',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fill in details to generate login credentials for your staff.',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: fullNameController,
                        decoration: InputDecoration(
                          hintText: 'Full Name (e.g. Ali Ahmed)',
                          prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        value: helperRole,
                        decoration: InputDecoration(
                          labelText: 'Role Category',
                          prefixIcon: const Icon(Icons.work_outline, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        items: ['Manager', 'Staff', 'Support']
                            .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                            .toList(),
                        onChanged: (v) => setStateDialog(() => helperRole = v!),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Login Email',
                          prefixIcon: const Icon(Icons.email_outlined, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Invalid email'
                            : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Password (min 6 chars)',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.length < 6 ? 'Min 6 chars' : null,
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        'Permissions:',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      Wrap(
                        spacing: 8,
                        children: [
                          'Manage Bookings',
                          'Manage Services',
                          'Customer Reviews',
                        ].map((perm) {
                          final isSel = selectedPermissions.contains(perm);
                          return FilterChip(
                            label: Text(perm),
                            selected: isSel,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 12,
                            ),
                            onSelected: (sel) {
                              setStateDialog(() {
                                if (sel) {
                                  selectedPermissions.add(perm);
                                } else {
                                  selectedPermissions.remove(perm);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) return;
                                    setStateDialog(() => isSaving = true);
                                    try {
                                      final error = await ref
                                          .read(authServiceProvider)
                                          .createHelperAccount(
                                            fullName:
                                                fullNameController.text.trim(),
                                            email: emailController.text.trim(),
                                            password: passwordController.text,
                                            roleCategory: helperRole,
                                            permissions: selectedPermissions,
                                          );

                                      if (context.mounted) {
                                        if (error != null) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $error'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        } else {
                                          Navigator.pop(context);
                                          ref.invalidate(helpersProvider);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Helper account created successfully!',
                                              ),
                                              backgroundColor: Color(0xFF10B981),
                                            ),
                                          );
                                        }
                                      }
                                    } finally {
                                      setStateDialog(() => isSaving = false);
                                    }
                                  },
                            icon: isSaving
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check_rounded, size: 16),
                            label: const Text('Create Account'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showViewHelperDialog(BuildContext context, User helper) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(helper.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${helper.email}'),
            const SizedBox(height: 6),
            Text('Role: ${helper.metadata['helper_role'] ?? 'Staff'}'),
            const SizedBox(height: 6),
            Text(
                'Permissions: ${(helper.metadata['permissions'] as List?)?.join(', ') ?? 'Manage Bookings'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showEditHelperDialog(BuildContext context, User helper) {
    final List<String> currentPerms = List<String>.from(
      helper.metadata['permissions'] as List? ??
          ['Manage Bookings', 'Manage Services'],
    );
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Text('Edit Permissions for ${helper.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Permissions:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    'Manage Bookings',
                    'Manage Services',
                    'Customer Reviews',
                  ].map((perm) {
                    final isSel = currentPerms.contains(perm);
                    return FilterChip(
                      label: Text(perm),
                      selected: isSel,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 12,
                      ),
                      onSelected: (sel) {
                        setStateDialog(() {
                          if (sel) {
                            currentPerms.add(perm);
                          } else {
                            currentPerms.remove(perm);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setStateDialog(() => isSaving = true);
                        try {
                          final updatedMeta =
                              Map<String, dynamic>.from(helper.metadata);
                          updatedMeta['permissions'] = currentPerms;

                          await ref.read(userProvider.notifier).updateUser(
                                helper.copyWith(metadata: updatedMeta),
                              );

                          if (context.mounted) {
                            Navigator.pop(context);
                            ref.invalidate(helpersProvider);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Helper updated successfully!'),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                          }
                        } finally {
                          setStateDialog(() => isSaving = false);
                        }
                      },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _removeHelper(BuildContext context, String helperId) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Remove Helper?',
      message:
          'Are you sure you want to remove this helper? They will lose access to your provider account.',
      confirmLabel: 'Yes, Remove',
      type: ConfirmationDialogType.danger,
      icon: Icons.person_remove_outlined,
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await ref.read(userProvider.notifier).deleteUser(helperId);
        ref.invalidate(helpersProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Helper removed successfully'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
}
