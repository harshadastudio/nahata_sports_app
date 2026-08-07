import 'package:flutter/material.dart';

import '../../../../core/services/session_manager.dart';
import '../../../../core/storage/profile_cache.dart';
import '../../core/coach_log.dart';
import '../navigation/coach_destination.dart';
import '../theme/coach_theme.dart';
import 'coach_attendance_page.dart';
import 'coach_enquiries_page.dart';
import 'coach_enrollments_page.dart';
import 'coach_fees_page.dart';
import 'coach_notifications_page.dart';
import 'coach_overview_page.dart';
import 'coach_profile_page.dart';
import 'coach_progress_page.dart';
import 'coach_scanner_page.dart';
import 'coach_schedule_page.dart';
import 'coach_students_page.dart';

/// The coach's home — the menu every other coach screen is reached from.
///
/// Replaces the old grid in `lib/dashboard/coach_screen.dart`, which routed to
/// screens built on the retired `nahatasports.com/api` and offered entries the
/// coach's permissions did not actually grant.
class CoachHomePage extends StatefulWidget {
  const CoachHomePage({super.key});

  @override
  State<CoachHomePage> createState() => _CoachHomePageState();
}

/// The name the rest of the app has always used for the coach landing screen.
///
/// `lib/dashboard/coach_screen.dart` re-exports this, so `auth/login.dart`,
/// `auth/registration.dart` and `main.dart` reach the rebuilt menu without an
/// import change. Kept as a wrapper rather than a `typedef` so the legacy call
/// sites that write `CoachHomeScreen()` without `const` still compile.
class CoachHomeScreen extends StatelessWidget {
  const CoachHomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const CoachHomePage();
}

class _CoachHomePageState extends State<CoachHomePage> {
  String? _name;
  String? _venue;

  @override
  void initState() {
    super.initState();
    CoachLog.life('CoachHomePage mounted');
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileCache.instance.read();
    if (!mounted || profile == null) return;

    // `sportComplex` is not a typed field on ProfileModel, so it arrives in
    // `extras` verbatim.
    final complex = profile.extras['sportComplex'];
    final venue = complex is Map ? complex['name']?.toString() : null;

    setState(() {
      _name = profile.name;
      _venue = (venue ?? '').isEmpty ? null : venue;
    });
  }

  void _open(CoachDestination destination) {
    CoachLog.ui('Menu → ${destination.label}');

    // Every destination is built today, but the status machinery is kept so a
    // future addition can be listed before it ships without dead-ending here.
    if (!destination.isReady) {
      _showPlanned(destination);
      return;
    }

    final page = switch (destination) {
      // The overview previews the enquiry queue, so it is handed a way to open
      // the full one rather than dead-ending at "View all".
      CoachDestination.overview => CoachOverviewPage(
          onOpenEnquiries: () => _open(CoachDestination.enquiries),
        ),
      CoachDestination.students => const CoachStudentsPage(),
      CoachDestination.enrollments => const CoachEnrollmentsPage(),
      CoachDestination.enquiries => const CoachEnquiriesPage(),
      CoachDestination.attendance => const CoachAttendancePage(),
      CoachDestination.scanner => const CoachScannerPage(),
      CoachDestination.schedule => const CoachSchedulePage(),
      CoachDestination.progress => const CoachProgressPage(),
      CoachDestination.feesManagement =>
        const CoachFeesPage(mode: CoachFeesMode.management),
      CoachDestination.feesApproval =>
        const CoachFeesPage(mode: CoachFeesMode.approval),
      CoachDestination.notifications => const CoachNotificationsPage(),
      CoachDestination.profile => const CoachProfilePage(),
    };

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  /// Says which screen is not in the app yet, and where it *is* available, so
  /// a coach is never left tapping a dead tile.
  void _showPlanned(CoachDestination destination) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CoachTokens.radiusMd),
        ),
        icon: Icon(destination.icon, size: 30, color: CoachTokens.brand),
        title: Text(
          destination.label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'This one is coming to the app in the next update. '
          'It is available on the coach dashboard on the website in the '
          'meantime.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: CoachTokens.brand),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CoachTokens.radiusMd),
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
            style: TextButton.styleFrom(foregroundColor: CoachTokens.textMuted),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: CoachTokens.danger),
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
    final destinations = CoachDestination.forCurrentUser();

    return Scaffold(
      backgroundColor: CoachTokens.canvas,
      body: CustomScrollView(
        slivers: [
          _header(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              CoachTokens.space4,
              CoachTokens.space4,
              CoachTokens.space4,
              CoachTokens.space8,
            ),
            sliver: SliverList.separated(
              itemCount: destinations.length + 1,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: CoachTokens.space3),
              itemBuilder: (context, index) {
                if (index == destinations.length) return _logoutTile();
                return _tile(destinations[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 148,
      backgroundColor: CoachTokens.brand,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Coach',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [CoachTokens.brand, Color(0xFF2B3FC4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            CoachTokens.space5,
            0,
            CoachTokens.space5,
            CoachTokens.space5,
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

  Widget _tile(CoachDestination destination) {
    final ready = destination.isReady;

    return CoachCard(
      onTap: () => _open(destination),
      padding: const EdgeInsets.symmetric(
        horizontal: CoachTokens.space4,
        vertical: CoachTokens.space4,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(CoachTokens.space3),
            decoration: BoxDecoration(
              color: ready
                  ? CoachTokens.brandSoft
                  : CoachTokens.canvas,
              borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
            ),
            child: Icon(
              destination.icon,
              size: 21,
              color: ready ? CoachTokens.brand : CoachTokens.textMuted,
            ),
          ),
          const SizedBox(width: CoachTokens.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        destination.label,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: ready
                              ? CoachTokens.textDark
                              : CoachTokens.textBody,
                        ),
                      ),
                    ),
                    if (!ready) ...[
                      const SizedBox(width: CoachTokens.space2),
                      const CoachStatusChip(
                        label: 'Soon',
                        color: CoachTokens.textMuted,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  destination.description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: CoachTokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: CoachTokens.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _logoutTile() {
    return CoachCard(
      onTap: _logout,
      padding: const EdgeInsets.symmetric(
        horizontal: CoachTokens.space4,
        vertical: CoachTokens.space4,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(CoachTokens.space3),
            decoration: BoxDecoration(
              color: CoachTokens.danger.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
            ),
            child: const Icon(
              Icons.logout_rounded,
              size: 21,
              color: CoachTokens.danger,
            ),
          ),
          const SizedBox(width: CoachTokens.space4),
          const Expanded(
            child: Text(
              'Log out',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: CoachTokens.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
