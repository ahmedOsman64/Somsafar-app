import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Manage Helpers'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0D3B66),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withAlpha(51)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You can create up to 3 helper accounts. Helpers can manage your bookings, services, and reviews, but cannot access your settings or financial reports.',
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Helpers (${helpers.length}/3)',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D3B66),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: helpers.length >= 3
                            ? null
                            : () => _showCreateHelperDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Create'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (helpers.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text(
                          'No helpers created yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        itemCount: helpers.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final helper = helpers[index];
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: Colors.grey.withAlpha(30),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFF1F5F9),
                                child: Text(
                                  helper.name.isNotEmpty
                                      ? helper.name
                                            .substring(0, 1)
                                            .toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D3B66),
                                  ),
                                ),
                              ),
                              title: Text(
                                helper.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (helper.metadata.containsKey(
                                        'username',
                                      )) ...[
                                        Text(
                                          '@${helper.metadata['username']}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.secondary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Text(
                                        helper.email,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (helper.metadata.containsKey(
                                    'helper_role',
                                  ))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        '${helper.metadata['helper_role']} • ${(helper.metadata['permissions'] as List?)?.join(', ') ?? 'No rules'}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.blue[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.visibility_outlined,
                                      color: Color(0xFF0D3B66),
                                    ),
                                    tooltip: 'View Helper',
                                    onPressed: () =>
                                        _showViewHelperDialog(context, helper),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      color: AppColors.secondary,
                                    ),
                                    tooltip: 'Edit Helper',
                                    onPressed: () =>
                                        _showEditHelperDialog(context, helper),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                    ),
                                    tooltip: 'Remove Helper',
                                    onPressed: () =>
                                        _removeHelper(context, helper.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
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
            backgroundColor: const Color(0xFFE9ECF1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            child: SingleChildScrollView(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create Helper',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Fill in the details to create a dedicated helper account.',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 24),

                      // Full Name
                      _buildFieldContainer(
                        TextFormField(
                          controller: fullNameController,
                          decoration: const InputDecoration(
                            hintText: 'Full Name',
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.badge_outlined,
                              color: Colors.black45,
                            ),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildFieldContainer(
                        DropdownButtonFormField<String>(
                          initialValue: helperRole,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Helper Role',
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.work_outline,
                              color: Colors.black45,
                            ),
                          ),
                          items: ['Manager', 'Staff', 'Support']
                              .map(
                                (r) =>
                                    DropdownMenuItem(value: r, child: Text(r)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setStateDialog(() => helperRole = v!),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildFieldContainer(
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'Helper Email (Username)',
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: Colors.black45,
                            ),
                          ),
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Invalid email'
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildFieldContainer(
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'Password (min 6 chars)',
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: Colors.black45,
                            ),
                          ),
                          validator: (v) =>
                              v == null || v.length < 6 ? 'Min 6 chars' : null,
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Text(
                        'Specific Rules / Permissions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...[
                        'Manage Bookings',
                        'Manage Services',
                        'View Reviews',
                        'Direct Support',
                      ].map(
                        (p) => CheckboxListTile(
                          title: Text(p, style: const TextStyle(fontSize: 14)),
                          value: selectedPermissions.contains(p),
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          activeColor: const Color(0xFF1DE9B6),
                          onChanged: (v) {
                            setStateDialog(() {
                              if (v == true) {
                                selectedPermissions.add(p);
                              } else {
                                selectedPermissions.remove(p);
                              }
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF0D3B66),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSaving || selectedPermissions.isEmpty
                                  ? null
                                  : () async {
                                      if (formKey.currentState!.validate()) {
                                        setStateDialog(() => isSaving = true);
                                        final authService = ref.read(
                                          authServiceProvider,
                                        );
                                        final currentUser = ref.read(
                                          authProvider,
                                        );

                                        if (currentUser != null) {
                                          final res = await authService
                                              .providerCreateHelper(
                                                fullName: fullNameController
                                                    .text
                                                    .trim(),
                                                username: emailController.text
                                                    .trim(), // Use email as username
                                                email: emailController.text
                                                    .trim(),
                                                password:
                                                    passwordController.text,
                                                providerId: currentUser.id,
                                                helperRole: helperRole,
                                                permissions:
                                                    selectedPermissions,
                                                providerEmail:
                                                    currentUser.email,
                                              );

                                          setStateDialog(
                                            () => isSaving = false,
                                          );
                                          if (context.mounted) {
                                            if (res != null &&
                                                res.containsKey('error')) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Error: ${res['error']}',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            } else {
                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Helper created successfully!',
                                                  ),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1DE9B6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const FittedBox(
                                      child: Text(
                                        'Create Account',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
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

  Widget _buildFieldContainer(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  void _showViewHelperDialog(BuildContext context, User helper) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: const Color(0xFFE2E8F0),
                    child: Text(
                      helper.name.isNotEmpty
                          ? helper.name.substring(0, 1).toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D3B66),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          helper.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D3B66),
                          ),
                        ),
                        if (helper.metadata.containsKey('username'))
                          Text(
                            '@${helper.metadata['username']}',
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildDetailItem(
                'Email Address',
                helper.email,
                Icons.email_outlined,
              ),
              _buildDetailItem(
                'Helper Role',
                helper.metadata['helper_role'] ?? 'Staff',
                Icons.work_outline,
              ),
              _buildDetailItem(
                'Account Status',
                helper.status.name.toUpperCase(),
                helper.status == UserStatus.active
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
              ),
              _buildDetailItem(
                'Created On',
                helper.createdAt?.toLocal().toString().split(' ')[0] ??
                    'Recently',
                Icons.calendar_month_outlined,
              ),

              const SizedBox(height: 24),
              const Text(
                'Assigned Permissions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    (helper.metadata['permissions'] as List?)
                        ?.map(
                          (p) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withAlpha(20),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.blue.withAlpha(50),
                              ),
                            ),
                            child: Text(
                              p.toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                        .toList() ??
                    [
                      const Text(
                        'No permissions assigned',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D3B66),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Close Details',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400], size: 20),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditHelperDialog(BuildContext context, User helper) {
    final fullNameController = TextEditingController(text: helper.name);
    final emailController = TextEditingController(text: helper.email);
    final formKey = GlobalKey<FormState>();

    String helperRole = helper.metadata['helper_role'] ?? 'Staff';
    final List<String> selectedPermissions = List<String>.from(
      helper.metadata['permissions'] as List? ?? [],
    );
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return Dialog(
            backgroundColor: const Color(0xFFE9ECF1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            child: SingleChildScrollView(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edit Helper Account',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Update the details for this helper account.',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      const SizedBox(height: 24),

                      // Full Name
                      _buildFieldContainer(
                        TextFormField(
                          controller: fullNameController,
                          decoration: const InputDecoration(
                            hintText: 'Full Name',
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.badge_outlined,
                              color: Colors.black45,
                            ),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildFieldContainer(
                        DropdownButtonFormField<String>(
                          initialValue: helperRole,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Helper Role',
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.work_outline,
                              color: Colors.black45,
                            ),
                          ),
                          items: ['Manager', 'Staff', 'Support']
                              .map(
                                (r) =>
                                    DropdownMenuItem(value: r, child: Text(r)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setStateDialog(() => helperRole = v!),
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildFieldContainer(
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'Helper Email (Username)',
                            border: InputBorder.none,
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: Colors.black45,
                            ),
                          ),
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Invalid email'
                              : null,
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Text(
                        'Specific Rules / Permissions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...[
                        'Manage Bookings',
                        'Manage Services',
                        'View Reviews',
                        'Direct Support',
                      ].map(
                        (p) => CheckboxListTile(
                          title: Text(p, style: const TextStyle(fontSize: 14)),
                          value: selectedPermissions.contains(p),
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          activeColor: const Color(0xFF1DE9B6),
                          onChanged: (v) {
                            setStateDialog(() {
                              if (v == true) {
                                selectedPermissions.add(p);
                              } else {
                                selectedPermissions.remove(p);
                              }
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF0D3B66),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isSaving || selectedPermissions.isEmpty
                                  ? null
                                  : () async {
                                      if (formKey.currentState!.validate()) {
                                        setStateDialog(() => isSaving = true);

                                        final updatedMetadata =
                                            Map<String, dynamic>.from(
                                              helper.metadata,
                                            );
                                        updatedMetadata['helper_role'] =
                                            helperRole;
                                        updatedMetadata['permissions'] =
                                            selectedPermissions;
                                        updatedMetadata['username'] =
                                            emailController.text
                                                .trim(); // Update username meta to match email

                                        final updatedUser = helper.copyWith(
                                          name: fullNameController.text.trim(),
                                          email: emailController.text.trim(),
                                          metadata: updatedMetadata,
                                        );

                                        try {
                                          await ref
                                              .read(userProvider.notifier)
                                              .updateUser(updatedUser);

                                          setStateDialog(
                                            () => isSaving = false,
                                          );
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Helper updated successfully!',
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          setStateDialog(
                                            () => isSaving = false,
                                          );
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Failed to update: ${e.toString().replaceAll('Exception: ', '')}',
                                                ),
                                                backgroundColor:
                                                    Colors.redAccent,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Save Changes',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
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

  void _removeHelper(BuildContext context, String helperId) async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Remove Helper?',
      message:
          'Are you sure you want to remove this helper account? They will lose access immediately.',
      confirmLabel: 'Yes, Remove',
      type: ConfirmationDialogType.danger,
      icon: Icons.person_remove_outlined,
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() => _isLoading = true);
      try {
        await ref.read(userProvider.notifier).deleteUser(helperId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Helper removed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to remove helper: $e'),
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
