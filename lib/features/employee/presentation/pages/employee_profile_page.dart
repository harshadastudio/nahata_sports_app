import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/storage/profile_cache.dart';
import '../../../../models/profile_model.dart';
import '../../../../repositories/auth_repository.dart';
import '../../core/employee_log.dart';
import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_staff_details.dart';
import '../navigation/employee_destination.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_stat_tile.dart';
import '../widgets/employee_states.dart';

/// My Profile — the employee's own account details.
///
/// **Read-only on purpose.** An employee record is created and maintained by an
/// admin (`/admin/employees/{id}` is an admin route), and there is no
/// self-service update endpoint for the EMPLOYEE role — so this shows what the
/// account holds and says who to ask, rather than offering fields that could
/// not be saved.
class EmployeeProfilePage extends StatefulWidget {
  const EmployeeProfilePage({super.key});

  @override
  State<EmployeeProfilePage> createState() => _EmployeeProfilePageState();
}

class _EmployeeProfilePageState extends State<EmployeeProfilePage> {
  final EmployeeDashboardRepositoryImpl _repository =
      EmployeeDashboardRepositoryImpl();

  ProfileModel? _profile;
  EmployeeStaffDetails _staff = EmployeeStaffDetails.empty;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _loadStaffDetails();
  }

  /// The employment record, pulled alongside the profile rather than after it.
  ///
  /// A failure here is swallowed on purpose: an employee whose login has no
  /// `Employee` row behind it yet is a real state right after an admin creates
  /// the account, and the identity card above is still worth showing.
  Future<void> _loadStaffDetails() async {
    try {
      final staff = await _repository.getStaffDetails();
      if (!mounted) return;
      setState(() => _staff = staff);
    } catch (e) {
      EmployeeLog.failure('Staff details failed', error: e);
    }
  }

  /// Shows the cached profile first so the page is never blank, then refreshes
  /// from the server behind it.
  Future<void> _load({bool refresh = false}) async {
    if (!refresh) {
      final cached = await ProfileCache.instance.read();
      if (mounted && cached != null) {
        setState(() {
          _profile = cached;
          _loading = false;
        });
      }
    }

    try {
      final fresh = await AuthRepository.instance.fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = fresh;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      EmployeeLog.failure('Profile refresh failed', error: e);
      if (!mounted) return;
      setState(() {
        // A failed refresh with a cached profile already on screen is not worth
        // an error state — the details shown are still the employee's own.
        if (_profile == null) {
          _error =
              e is ApiException ? e.message : 'Could not load your profile.';
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EmployeeTokens.canvas,
      appBar: AppBar(
        backgroundColor: EmployeeTokens.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        color: EmployeeTokens.brand,
        onRefresh: () => Future.wait([
          _load(refresh: true),
          _loadStaffDetails(),
        ]),
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading && _profile == null) {
      return ListView(
        padding: const EdgeInsets.all(EmployeeTokens.space4),
        children: const [EmployeeListShimmer(rows: 4)],
      );
    }

    if (_profile == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: EmployeeTokens.space8),
          EmployeeErrorView(
            message: _error ?? 'Could not load your profile.',
            onRetry: () => _load(refresh: true),
          ),
        ],
      );
    }

    final profile = _profile!;
    final complex = profile.extras['sportComplex'];
    final venueName = complex is Map ? complex['name']?.toString() : null;

    // The employment record carries the complex, status and joining date more
    // authoritatively than the login does, so those rows drop off the login
    // card once it has arrived — otherwise the same values appear twice under
    // two names. Without it, the login card carries everything as before.
    final hasStaffDetails = !_staff.isEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        EmployeeTokens.space4,
        EmployeeTokens.space4,
        EmployeeTokens.space4,
        EmployeeTokens.space8,
      ),
      children: [
        _identityCard(profile),
        const SizedBox(height: EmployeeTokens.space4),
        EmployeeCard(
          child: Column(
            children: [
              _row(Icons.badge_outlined, 'Role', profile.roleLabel),
              _row(Icons.mail_outline_rounded, 'Email', profile.email ?? ''),
              _row(
                Icons.phone_outlined,
                'Phone',
                profile.phoneNumber ?? '',
                isLast: hasStaffDetails,
              ),
              if (!hasStaffDetails) ...[
                _row(Icons.place_outlined, 'Complex', venueName ?? ''),
                _row(
                  Icons.verified_user_outlined,
                  'Account',
                  profile.status ?? '',
                ),
                _row(
                  Icons.event_outlined,
                  'Joined',
                  profile.joinDate ?? '',
                  isLast: true,
                ),
              ],
            ],
          ),
        ),
        for (final section in _staff.sections) ...[
          const SizedBox(height: EmployeeTokens.space4),
          _staffSection(section),
        ],
        const SizedBox(height: EmployeeTokens.space4),
        _accessCard(),
        const SizedBox(height: EmployeeTokens.space4),
        _adminNotice(),
      ],
    );
  }

  /// One block of admin-entered details, laid out as a two-column grid of
  /// label/value tiles — the same shape the website's profile uses.
  ///
  /// The fields are untyped label/value pairs, so nothing here knows or cares
  /// which ones a given role returns; a new field on the admin form appears on
  /// this screen without a change.
  Widget _staffSection(EmployeeStaffSection section) {
    return EmployeeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_outlined,
                size: 18,
                color: EmployeeTokens.brand,
              ),
              const SizedBox(width: EmployeeTokens.space2),
              Expanded(
                child: Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: EmployeeTokens.textDark,
                  ),
                ),
              ),
              const EmployeeChip(
                label: 'Read-only',
                color: EmployeeTokens.textMuted,
                icon: Icons.lock_outline_rounded,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: EmployeeTokens.space4),
          // `EmployeeTileGrid` rather than a GridView: these values are text,
          // so a tile's height has to follow the content and the font scale.
          EmployeeTileGrid(
            children: [
              for (final field in section.fields) _staffField(field),
            ],
          ),
        ],
      ),
    );
  }

  Widget _staffField(EmployeeStaffField field) {
    return Container(
      padding: const EdgeInsets.all(EmployeeTokens.space3),
      decoration: BoxDecoration(
        color: EmployeeTokens.canvas,
        borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            field.label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9.5,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w700,
              color: EmployeeTokens.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            field.value,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: EmployeeTokens.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _identityCard(ProfileModel profile) {
    final name = (profile.name ?? '').trim();

    return EmployeeCard(
      padding: const EdgeInsets.all(EmployeeTokens.space5),
      child: Row(
        children: [
          EmployeeAvatar(
            initial: name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
            imageUrl: profile.imageUrl,
            radius: 30,
          ),
          const SizedBox(width: EmployeeTokens.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Employee' : name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: EmployeeTokens.textDark,
                  ),
                ),
                if ((profile.email ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    profile.email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: EmployeeTokens.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: EmployeeTokens.space2 + 2),
                EmployeeChip(
                  label: profile.roleLabel,
                  color: EmployeeTokens.brand,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// What this employee is actually allowed to open, derived from the same
  /// permission set the menu is built from — so they can see why a section is
  /// missing without asking.
  Widget _accessCard() {
    final granted = EmployeeDestination.values
        .where((d) =>
            !d.alwaysShow &&
            PermissionService.instance.hasPermission(d.permission))
        .toList(growable: false);

    if (granted.isEmpty) return const SizedBox.shrink();

    return EmployeeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What you can access',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: EmployeeTokens.textDark,
            ),
          ),
          const SizedBox(height: EmployeeTokens.space3),
          Wrap(
            spacing: EmployeeTokens.space2,
            runSpacing: EmployeeTokens.space2,
            children: granted
                .map(
                  (d) => EmployeeChip(
                    label: d.label,
                    color: EmployeeTokens.info,
                    icon: d.icon,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _adminNotice() {
    return Container(
      padding: const EdgeInsets.all(EmployeeTokens.space4),
      decoration: BoxDecoration(
        color: EmployeeTokens.brandSoft,
        borderRadius: BorderRadius.circular(EmployeeTokens.radiusMd),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 19,
            color: EmployeeTokens.brand,
          ),
          SizedBox(width: EmployeeTokens.space3),
          Expanded(
            child: Text(
              'Your account, the complex you are attached to, and the sections '
              'you can open are all managed by an admin. Ask them to change '
              'anything here.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: EmployeeTokens.textBody,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    IconData icon,
    String label,
    String value, {
    bool isLast = false,
  }) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: EmployeeTokens.space3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: EmployeeTokens.textMuted),
              const SizedBox(width: EmployeeTokens.space3),
              SizedBox(
                width: 78,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: EmployeeTokens.textMuted,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: EmployeeTokens.textDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: EmployeeTokens.border),
      ],
    );
  }
}
