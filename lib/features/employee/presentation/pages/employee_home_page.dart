import 'package:flutter/material.dart';

import '../../../../core/services/session_manager.dart';
import '../../../../core/storage/profile_cache.dart';
import '../../core/employee_log.dart';
import '../navigation/employee_destination.dart';
import '../theme/employee_theme.dart';
import 'employee_attendance_page.dart';
import 'employee_batches_page.dart';
import 'employee_blocked_slots_page.dart';
import 'employee_bookings_page.dart';
import 'employee_coaches_page.dart';
import 'employee_courts_page.dart';
import 'employee_enquiries_page.dart';
import 'employee_fees_approval_page.dart';
import 'employee_fees_management_page.dart';
import 'employee_notifications_page.dart';
import 'employee_overview_page.dart';
import 'employee_payments_page.dart';
import 'employee_profile_page.dart';
import 'employee_slots_page.dart';
import 'employee_sports_page.dart';
import 'employee_users_page.dart';

/// The employee's home — the menu every other employee screen is reached from.
///
/// Mirrors the `EMPLOYEE` block of the website's sidebar entry-for-entry, but
/// bucketed under two headings: seventeen flat rows works in a sidebar and does
/// not on a phone.
class EmployeeHomePage extends StatefulWidget {
  const EmployeeHomePage({super.key});

  @override
  State<EmployeeHomePage> createState() => _EmployeeHomePageState();
}

/// The name the rest of the app routes to, matching `CoachHomeScreen`.
///
/// Kept as a wrapper rather than a `typedef` so a call site that writes
/// `EmployeeHomeScreen()` without `const` still compiles.
class EmployeeHomeScreen extends StatelessWidget {
  const EmployeeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const EmployeeHomePage();
}

class _EmployeeHomePageState extends State<EmployeeHomePage> {
  String? _name;
  String? _venue;

  @override
  void initState() {
    super.initState();
    EmployeeLog.life('EmployeeHomePage mounted');
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileCache.instance.read();
    if (!mounted || profile == null) return;

    // `sportComplex` is not a typed field on ProfileModel, so it arrives in
    // `extras` verbatim. It is the one thing on this screen worth showing
    // prominently — every module below is scoped to it.
    final complex = profile.extras['sportComplex'];
    final venue = complex is Map ? complex['name']?.toString() : null;

    setState(() {
      _name = profile.name;
      _venue = (venue ?? '').isEmpty ? null : venue;
    });
  }

  void _open(EmployeeDestination destination) {
    EmployeeLog.ui('Menu → ${destination.label}');

    final page = switch (destination) {
      EmployeeDestination.overview => EmployeeOverviewPage(
          onOpenBookings: () => _open(EmployeeDestination.bookings),
        ),
      EmployeeDestination.bookings => const EmployeeBookingsPage(),
      EmployeeDestination.payments => const EmployeePaymentsPage(),
      EmployeeDestination.attendance => const EmployeeAttendancePage(),
      EmployeeDestination.coaches => const EmployeeCoachesPage(),
      EmployeeDestination.enquiries => const EmployeeEnquiriesPage(),
      EmployeeDestination.feesApproval => const EmployeeFeesApprovalPage(),
      EmployeeDestination.users => const EmployeeUsersPage(),
      EmployeeDestination.notifications => const EmployeeNotificationsPage(),
      EmployeeDestination.blockedSlots => const EmployeeBlockedSlotsPage(),
      EmployeeDestination.feesManagement => const EmployeeFeesManagementPage(),
      EmployeeDestination.sports => const EmployeeSportsPage(),
      EmployeeDestination.courts => const EmployeeCourtsPage(),
      EmployeeDestination.slots => const EmployeeSlotsPage(),
      EmployeeDestination.batches => const EmployeeBatchesPage(),
      EmployeeDestination.profile => const EmployeeProfilePage(),
    };

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EmployeeTokens.radiusMd),
        ),
        title: const Text(
          'Log out?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          "You'll need to sign in again to open your dashboard.",
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: EmployeeTokens.textMuted,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: EmployeeTokens.danger,
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // SessionManager revokes the refresh token, clears local state and routes
    // back to Login itself — nothing to navigate here.
    await SessionManager.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = EmployeeDestination.groupedForCurrentUser();

    return Scaffold(
      backgroundColor: EmployeeTokens.canvas,
      body: CustomScrollView(
        slivers: [
          _header(),
          for (final entry in grouped.entries) ...[
            SliverToBoxAdapter(child: _groupHeader(entry.key)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: EmployeeTokens.space4,
              ),
              sliver: SliverList.separated(
                itemCount: entry.value.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: EmployeeTokens.space3),
                itemBuilder: (context, index) => _tile(entry.value[index]),
              ),
            ),
          ],
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              EmployeeTokens.space4,
              EmployeeTokens.space5,
              EmployeeTokens.space4,
              EmployeeTokens.space8,
            ),
            sliver: SliverToBoxAdapter(child: _logoutTile()),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 148,
      backgroundColor: EmployeeTokens.brand,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Employee',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [EmployeeTokens.brand, Color(0xFF2B3FC4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            EmployeeTokens.space5,
            0,
            EmployeeTokens.space5,
            EmployeeTokens.space5,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _name == null ? 'Welcome back' : 'Hi, ${_name!}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_venue != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _venue!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupHeader(EmployeeMenuGroup group) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        EmployeeTokens.space5,
        EmployeeTokens.space5,
        EmployeeTokens.space5,
        EmployeeTokens.space3,
      ),
      child: Text(
        group.label.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          color: EmployeeTokens.textMuted,
        ),
      ),
    );
  }

  Widget _tile(EmployeeDestination destination) {
    return EmployeeCard(
      onTap: () => _open(destination),
      padding: const EdgeInsets.symmetric(
        horizontal: EmployeeTokens.space4,
        vertical: EmployeeTokens.space4,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(EmployeeTokens.space3),
            decoration: BoxDecoration(
              color: EmployeeTokens.brandSoft,
              borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
            ),
            child: Icon(
              destination.icon,
              size: 21,
              color: EmployeeTokens.brand,
            ),
          ),
          const SizedBox(width: EmployeeTokens.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destination.label,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: EmployeeTokens.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  destination.description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: EmployeeTokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: EmployeeTokens.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _logoutTile() {
    return EmployeeCard(
      onTap: _logout,
      padding: const EdgeInsets.symmetric(
        horizontal: EmployeeTokens.space4,
        vertical: EmployeeTokens.space4,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(EmployeeTokens.space3),
            decoration: BoxDecoration(
              color: EmployeeTokens.danger.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
            ),
            child: const Icon(
              Icons.logout_rounded,
              size: 21,
              color: EmployeeTokens.danger,
            ),
          ),
          const SizedBox(width: EmployeeTokens.space4),
          const Expanded(
            child: Text(
              'Log out',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: EmployeeTokens.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
