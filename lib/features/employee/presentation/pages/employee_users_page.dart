import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_user.dart';
import '../state/employee_users_controller.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_forms.dart';
import '../widgets/employee_list_scaffold.dart';

/// Users Management — app accounts.
///
/// View and edit only; creating and deleting a user are admin-only routes.
class EmployeeUsersPage extends StatefulWidget {
  const EmployeeUsersPage({super.key});

  @override
  State<EmployeeUsersPage> createState() => _EmployeeUsersPageState();
}

class _EmployeeUsersPageState extends State<EmployeeUsersPage> {
  late final EmployeeUsersController _controller =
      EmployeeUsersController(EmployeeDashboardRepositoryImpl());
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wrapped so the empty-state copy tracks the filters.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => EmployeeListScaffold<EmployeeUser>(
        title: 'Users',
        controller: _controller,
        subtitle: () =>
            '${_controller.total} user${_controller.total == 1 ? '' : 's'}',
        filters: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EmployeeSearchBar(
              controller: _search,
              hintText: 'Search users by name, email or phone',
              onChanged: _controller.onSearchChanged,
              onClear: () => _controller.onSearchChanged(''),
            ),
            const SizedBox(height: EmployeeTokens.space3),
            EmployeeFilterChips<String>(
              values: employeeUserStatuses,
              selected: _controller.status,
              labelOf: (s) => s,
              allLabel: 'All statuses',
              onChanged: _controller.setStatus,
            ),
            const SizedBox(height: EmployeeTokens.space2),
            EmployeeFilterChips<String>(
              values: employeeMembershipTypes,
              selected: _controller.membershipType,
              labelOf: (m) => m,
              allLabel: 'All memberships',
              onChanged: _controller.setMembershipType,
            ),
          ],
        ),
        itemBuilder: (context, user) => _userCard(user),
        emptyIcon: Icons.people_alt_outlined,
        emptyTitle: 'No users found',
        emptyMessage: _controller.isFiltered
            ? 'Nothing matches these filters.'
            : 'App accounts will show up here.',
      ),
    );
  }

  Widget _userCard(EmployeeUser user) {
    return EmployeeCard(
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space3),
      accentColor:
          user.isActive ? EmployeeTokens.success : EmployeeTokens.danger,
      onTap: () => _openDetail(user),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmployeeAvatar(
            initial: user.initial,
            imageUrl: user.avatar,
            radius: 20,
          ),
          const SizedBox(width: EmployeeTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: EmployeeTokens.textDark,
                        ),
                      ),
                    ),
                    if (user.role.toUpperCase() != 'USER') ...[
                      const SizedBox(width: EmployeeTokens.space2),
                      EmployeeChip(
                        label: user.roleLabel,
                        color: EmployeeTokens.purple,
                        dense: true,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: EmployeeTokens.textMuted,
                  ),
                ),
                const SizedBox(height: EmployeeTokens.space2),
                // Wrap so a long phone number and the booking count fall onto
                // two lines instead of running off the card.
                Wrap(
                  spacing: EmployeeTokens.space3,
                  runSpacing: EmployeeTokens.space1,
                  children: [
                    if (user.phoneNumber.isNotEmpty)
                      _meta(Icons.phone_outlined, user.phoneNumber),
                    _meta(
                      Icons.event_note_outlined,
                      '${user.totalBookings} booking'
                      '${user.totalBookings == 1 ? '' : 's'}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: EmployeeTokens.space2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              EmployeeChip(label: user.status, dense: true),
              if ((user.membershipType ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                EmployeeChip(
                  label: user.membershipType!,
                  color: EmployeeTokens.info,
                  dense: true,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// A small icon-and-label pair for the card's meta line.
  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: EmployeeTokens.textMuted),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11.5,
            color: EmployeeTokens.textBody,
          ),
        ),
      ],
    );
  }

  Future<void> _openDetail(EmployeeUser user) {
    return showEmployeeSheet<void>(
      context: context,
      title: user.displayName,
      subtitle: user.roleLabel,
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EmployeeAvatar(
                initial: user.initial,
                imageUrl: user.avatar,
                radius: 28,
              ),
              const SizedBox(width: EmployeeTokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: EmployeeTokens.textDark,
                      ),
                    ),
                    const SizedBox(height: EmployeeTokens.space2),
                    EmployeeChip(label: user.status),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: EmployeeTokens.space5),
          EmployeeDetailRow(label: 'Email', value: user.email),
          EmployeeDetailRow(label: 'Phone', value: user.phoneNumber),
          EmployeeDetailRow(label: 'Role', value: user.roleLabel),
          EmployeeDetailRow(
            label: 'Membership',
            value: user.membershipType ?? '',
          ),
          EmployeeDetailRow(
            label: 'Bookings',
            value: '${user.totalBookings}',
          ),
          EmployeeDetailRow(label: 'Joined', value: user.joinDate ?? ''),
          EmployeeDetailRow(label: 'Last active', value: user.lastActive ?? ''),
          const SizedBox(height: EmployeeTokens.space5),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(sheetContext).pop();
              _openEdit(user);
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit user'),
            style: FilledButton.styleFrom(
              backgroundColor: EmployeeTokens.brand,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEdit(EmployeeUser user) {
    return showEmployeeSheet<void>(
      context: context,
      title: 'Edit user',
      subtitle: user.displayName,
      builder: (context) => _UserForm(user: user, controller: _controller),
    );
  }
}

class _UserForm extends StatefulWidget {
  const _UserForm({required this.user, required this.controller});

  final EmployeeUser user;
  final EmployeeUsersController controller;

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.user.name);
  late final TextEditingController _phone =
      TextEditingController(text: widget.user.phoneNumber);
  late final TextEditingController _email =
      TextEditingController(text: widget.user.email);

  late String _membership = employeeMembershipTypes.contains(
    widget.user.membershipType,
  )
      ? widget.user.membershipType!
      : employeeMembershipTypes.first;

  late String _status = employeeUserStatuses.contains(widget.user.status)
      ? widget.user.status
      : employeeUserStatuses.first;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'A name is required.');
      return;
    }
    if (_email.text.trim().isEmpty) {
      setState(() => _error = 'An email address is required.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await widget.controller.save(
      widget.user,
      name: _name.text,
      phoneNumber: _phone.text,
      email: _email.text,
      membershipType: _membership,
      status: _status,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }

    Navigator.of(context).pop();
    showEmployeeToast(context, 'User updated');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmployeeFormError(message: _error),

        EmployeeField(
          label: 'Full name',
          required: true,
          child: EmployeeTextField(
            controller: _name,
            prefixIcon: Icons.person_outline_rounded,
            hintText: 'Their name',
          ),
        ),

        EmployeeField(
          label: 'Mobile number',
          child: EmployeeTextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textCapitalization: TextCapitalization.none,
            prefixIcon: Icons.phone_outlined,
            hintText: '10-digit number',
          ),
        ),

        EmployeeField(
          label: 'Email address',
          required: true,
          child: EmployeeTextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
            prefixIcon: Icons.mail_outline_rounded,
            hintText: 'name@example.com',
          ),
        ),

        EmployeeField(
          label: 'Membership',
          child: EmployeeDropdown<String>(
            value: _membership,
            items: employeeMembershipTypes,
            labelOf: (m) => m,
            onChanged: (value) =>
                setState(() => _membership = value ?? _membership),
          ),
        ),

        EmployeeField(
          label: 'Account status',
          hint: 'Blocking an account stops them signing in and booking.',
          child: EmployeeDropdown<String>(
            value: _status,
            items: employeeUserStatuses,
            labelOf: (s) => s,
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
        ),

        Container(
          padding: const EdgeInsets.all(EmployeeTokens.space3),
          margin: const EdgeInsets.only(bottom: EmployeeTokens.space4),
          decoration: BoxDecoration(
            color: EmployeeTokens.canvas,
            borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 15,
                color: EmployeeTokens.textMuted,
              ),
              const SizedBox(width: EmployeeTokens.space2),
              Expanded(
                child: Text(
                  // Spelling out why the field is missing beats leaving a
                  // disabled dropdown the user will try to tap.
                  'Their role stays ${widget.user.roleLabel}. Changing someone'
                  "'s role is an admin action.",
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: EmployeeTokens.textBody,
                  ),
                ),
              ),
            ],
          ),
        ),

        EmployeeSheetActions(
          saving: _saving,
          saveLabel: 'Update user',
          onSave: _save,
        ),
      ],
    );
  }
}
