import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/network/api_exception.dart';
import '../models/attendance_record_model.dart';
import '../models/profile_model.dart';
import '../models/student_profile_model.dart';
import '../providers/profile_provider.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';
import 'morescreen.dart' show EditProfileScreen;

/// Everything the API knows about the signed-in user, on one screen.
///
/// Two calls, because no single endpoint holds it all:
///
///  * `GET /auth/profile` — the account: name, contact, role, membership,
///    status, the venue a staff login is scoped to.
///  * `GET /students/me` — the student record hanging off that account: parent
///    contact, school, medical notes, enrolment. Absent for staff logins, so a
///    404 or a null here is a missing section rather than an error.
///
/// The cached profile paints first so the screen is never blank, then the two
/// calls refresh it. A network failure with a cached profile on screen is a
/// banner, not an empty page.
class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  ProfileModel? _profile;
  StudentProfile? _student;

  /// `GET /attendance/my`. Null means the section has nothing to say — the
  /// call failed, or this account is not one the route serves. An empty list
  /// is a real answer and gets its own line.
  List<AttendanceRecord>? _attendance;
  bool _attendanceLoading = true;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Cached first: the screen opens filled in, and the network call only ever
    // improves what is already there.
    final cached = await AuthRepository.instance.cachedProfile();
    if (cached != null && mounted) {
      setState(() {
        _profile = cached;
        _loading = false;
      });
    }

    try {
      final profile = await AuthRepository.instance.fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _error = null;
      });
      context.read<ProfileProvider>().adopt(profile);

      // Staff accounts have no student record; a null is a missing section,
      // not a failure, so it is fetched after the profile is already on screen.
      final student = await UserRepository.instance.fetchMyStudentProfile();
      if (!mounted) return;
      setState(() => _student = student);

      await _loadAttendance();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load your profile.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The attendance history, kept off the critical path.
  ///
  /// Its own method because it swallows its own failures: the rest of the
  /// profile is already on screen by the time this runs, and a history that
  /// could not be read is a section that does not appear — not a banner over
  /// details that loaded perfectly well.
  Future<void> _loadAttendance() async {
    if (mounted) setState(() => _attendanceLoading = true);

    final records = await UserRepository.instance.fetchMyAttendance();

    if (!mounted) return;
    setState(() {
      _attendance = records;
      _attendanceLoading = false;
    });
  }

  Future<void> _openEditor() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    // The editor writes the name, the phone and the photo, so the screen is
    // re-read rather than left showing what it opened with.
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text(
          'My Profile',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Edit profile',
            onPressed: profile == null ? null : _openEditor,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: profile == null
          ? _loading
                ? const Center(child: CircularProgressIndicator())
                : _EmptyState(
                    message: _error ?? 'No profile found.',
                    onRetry: _load,
                  )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  if (_error != null) _ErrorBanner(message: _error!),
                  _Header(profile: profile),
                  const SizedBox(height: 16),
                  ..._sections(profile),
                ],
              ),
            ),
    );
  }

  /// The cards, in order, dropping any that has nothing in it. A card full of
  /// dashes says less than no card at all.
  List<Widget> _sections(ProfileModel profile) {
    final student = _student;
    final user = student?.user;

    final account = _Section(
      title: 'Account',
      icon: Icons.person_outline,
      rows: [
        _Row('Name', profile.name),
        _Row('Email', profile.email),
        _Row('Phone', profile.phoneNumber),
        _Row('Date of birth', profile.dob ?? user?.dob),
        _Row('Gender', profile.gender ?? user?.gender),
        _Row('Blood group', profile.bloodGroup ?? user?.bloodGroup),
        _Row('User ID', profile.id?.toString()),
      ],
    );

    final membership = _Section(
      title: 'Membership',
      icon: Icons.card_membership_outlined,
      rows: [
        _Row('Role', profile.roleLabel),
        _Row('Membership', profile.membershipType),
        _Row('Status', profile.status ?? student?.effectiveStatus),
        _Row('Total bookings', profile.totalBookings?.toString()),
        _Row('Member since', profile.joinDate ?? user?.joinDate),
        _Row('Last active', profile.lastActive),
        _Row('Sports complex', profile.sportComplex?.label),
        // Only ever set on a Google sign-in, so it explains an account with
        // no password rather than looking like a stray field.
        _Row('Signed in with', profile.isGoogleUser ? 'Google' : null),
      ],
    );

    final staff = _Section(
      title: 'Staff details',
      icon: Icons.badge_outlined,
      rows: [
        _Row('Employee ID', profile.employeeId),
        _Row('Department', profile.department),
        _Row('Assigned location', profile.assignedLocation),
        _Row(
          'Assigned sports',
          profile.assignedSports.isEmpty
              ? null
              : profile.assignedSports.join(', '),
        ),
      ],
    );

    final widgets = <Widget>[];

    void add(_Section section) {
      if (section.hasContent) widgets.add(section);
    }

    add(account);
    add(membership);

    // Attendance sits directly below membership: it is the history behind the
    // status that card reports.
    final attendance = _attendanceCard();
    if (attendance != null) widgets.add(attendance);

    add(staff);

    if (student != null) {
      add(
        _Section(
          title: 'Student record',
          icon: Icons.school_outlined,
          rows: [
            _Row('Student ID', student.id?.toString()),
            _Row('School', student.schoolName),
            _Row('Grade', student.grade),
            _Row('Enrolled on', student.enrollmentDate),
            _Row('Previous experience', student.previousExperience),
            _Row('Achievements', student.achievements),
          ],
        ),
      );
      add(
        _Section(
          title: 'Parent / guardian',
          icon: Icons.family_restroom_outlined,
          rows: [
            _Row('Name', student.parentName),
            _Row('Phone', student.parentPhone),
            _Row('Email', student.parentEmail),
          ],
        ),
      );
      add(
        _Section(
          title: 'Medical',
          icon: Icons.medical_information_outlined,
          rows: [
            _Row('Conditions', student.medicalConditions),
            _Row('Allergies', student.allergies),
            _Row('Blood group', user?.bloodGroup ?? profile.bloodGroup),
          ],
        ),
      );
    }

    return widgets;
  }

  /// The attendance card, or null when there is nothing to show.
  ///
  /// Null only for a call that failed or an account the route does not serve;
  /// an empty history still gets a card, because "no sessions yet" is an
  /// answer and a missing card would read as a broken screen.
  Widget? _attendanceCard() {
    if (_attendanceLoading) {
      return const _AttendanceCard.loading();
    }

    final records = _attendance;
    if (records == null) return null;

    return _AttendanceCard(records: records);
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final ProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final image = profile.imageUrl;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: Colors.blueAccent,
            backgroundImage: (image != null && image.isNotEmpty)
                ? CachedNetworkImageProvider(image)
                : null,
            child: (image != null && image.isNotEmpty)
                ? null
                : Text(
                    profile.initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            profile.displayName.isEmpty ? 'Your Name' : profile.displayName,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if ((profile.email ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              profile.email!,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (profile.roleLabel.isNotEmpty)
                _Chip(label: profile.roleLabel, color: Colors.blueAccent),
              if ((profile.status ?? '').isNotEmpty)
                _Chip(
                  label: profile.status!,
                  color: profile.isActive ? Colors.green : Colors.orange,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `GET /attendance/my`, rendered as a session history.
///
/// Sits below Membership because it is the record behind the status shown
/// there. Long histories collapse to the ten most recent with an explicit
/// count, so nothing is dropped without saying so.
class _AttendanceCard extends StatefulWidget {
  const _AttendanceCard({required this.records}) : loading = false;

  const _AttendanceCard.loading() : records = const [], loading = true;

  final List<AttendanceRecord> records;
  final bool loading;

  @override
  State<_AttendanceCard> createState() => _AttendanceCardState();
}

class _AttendanceCardState extends State<_AttendanceCard> {
  static const int _collapsedCount = 10;

  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final records = widget.records;
    final showAll = _expanded || records.length <= _collapsedCount;
    final visible = showAll ? records : records.take(_collapsedCount).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fact_check_outlined,
                size: 18,
                color: Colors.blueAccent,
              ),
              const SizedBox(width: 8),
              const Text(
                'Attendance',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              if (!widget.loading && records.isNotEmpty)
                Text(
                  _summary(records),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
            ],
          ),
          const Divider(height: 20),

          if (widget.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Loading your sessions…',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            )
          else if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'No sessions recorded yet.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            )
          else ...[
            for (final record in visible) _AttendanceRow(record: record),
            if (!showAll)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _expanded = true),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Show all ${records.length}'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// `"3 sessions · 3 present"`, dropping the second half when nothing was
  /// marked present so it never reads as "0 present" for an absent-only list.
  static String _summary(List<AttendanceRecord> records) {
    final present = records.where((r) => r.isPresent).length;
    final sessions =
        '${records.length} '
        '${records.length == 1 ? 'session' : 'sessions'}';
    return present == 0 ? sessions : '$sessions · $present present';
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final times = [
      if (record.checkInLabel != null) 'In ${record.checkInLabel}',
      if (record.checkOutLabel != null) 'Out ${record.checkOutLabel}',
    ].join('  ·  ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _statusColor(record),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.dateLabel,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                if (record.sessionLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    record.sessionLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Colors.black54,
                    ),
                  ),
                ],
                if (times.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    times,
                    style: const TextStyle(fontSize: 12, color: Colors.black38),
                  ),
                ],
                if (record.notes != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    record.notes!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black45,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if ((record.status ?? '').isNotEmpty) ...[
            const SizedBox(width: 8),
            _Chip(label: record.status!, color: _statusColor(record)),
          ],
        ],
      ),
    );
  }

  static Color _statusColor(AttendanceRecord record) {
    if (record.isAbsent) return Colors.red;
    if ((record.status ?? '').toLowerCase() == 'late') return Colors.orange;
    if (record.isPresent) return Colors.green;
    return Colors.blueGrey;
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// One label/value pair. A null or blank [value] means the API did not send
/// the field, and the row is dropped instead of printed as an empty line.
class _Row {
  _Row(this.label, String? value) : value = _clean(value);

  final String label;
  final String? value;

  bool get isPresent => value != null;

  static String? _clean(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }
}

class _Section extends StatelessWidget {
  _Section({required this.title, required this.icon, required List<_Row> rows})
    : rows = rows.where((row) => row.isPresent).toList();

  final String title;
  final IconData icon;
  final List<_Row> rows;

  bool get hasContent => rows.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          for (final row in rows) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      row.label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value!,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, size: 18, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$message Showing your last saved details.',
              style: const TextStyle(fontSize: 12.5, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_off_outlined,
              size: 48,
              color: Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
