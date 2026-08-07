import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../core/storage/profile_cache.dart';
import '../../../../models/profile_model.dart';
import '../../../../repositories/auth_repository.dart';
import '../../core/coach_log.dart';
import '../navigation/coach_destination.dart';
import '../theme/coach_theme.dart';
import '../widgets/coach_states.dart';

/// My Profile — the coach's own account details.
///
/// **Read-only on purpose.** A coach record is created and maintained by an
/// admin (`/coaches/{id}` is an admin route), and there is no self-service
/// update endpoint for the COACH role — so this shows what the account holds
/// and says who to ask, rather than offering fields that could not be saved.
class CoachProfilePage extends StatefulWidget {
  const CoachProfilePage({super.key});

  @override
  State<CoachProfilePage> createState() => _CoachProfilePageState();
}

class _CoachProfilePageState extends State<CoachProfilePage> {
  ProfileModel? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
      CoachLog.failure('Profile refresh failed', error: e);
      if (!mounted) return;
      setState(() {
        // A failed refresh with a cached profile already on screen is not
        // worth an error state — the details shown are still the coach's own.
        if (_profile == null) {
          _error = e is ApiException
              ? e.message
              : 'Could not load your profile.';
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoachTokens.canvas,
      appBar: AppBar(
        backgroundColor: CoachTokens.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        color: CoachTokens.brand,
        onRefresh: () => _load(refresh: true),
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading && _profile == null) {
      return ListView(
        padding: const EdgeInsets.all(CoachTokens.space4),
        children: const [CoachListShimmer(rows: 4)],
      );
    }

    if (_profile == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: CoachTokens.space8),
          CoachErrorView(
            message: _error ?? 'Could not load your profile.',
            onRetry: () => _load(refresh: true),
          ),
        ],
      );
    }

    final profile = _profile!;
    final venue = profile.extras['sportComplex'];
    final venueName = venue is Map ? venue['name']?.toString() : null;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        CoachTokens.space4,
        CoachTokens.space4,
        CoachTokens.space4,
        CoachTokens.space8,
      ),
      children: [
        _identityCard(profile),
        const SizedBox(height: CoachTokens.space4),
        CoachCard(
          child: Column(
            children: [
              _row(Icons.badge_outlined, 'Role', profile.roleLabel),
              _row(Icons.mail_outline_rounded, 'Email', profile.email ?? ''),
              _row(Icons.phone_outlined, 'Phone', profile.phoneNumber ?? ''),
              _row(Icons.place_outlined, 'Venue', venueName ?? ''),
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
          ),
        ),
        const SizedBox(height: CoachTokens.space4),
        _accessCard(),
        const SizedBox(height: CoachTokens.space4),
        _adminNotice(),
      ],
    );
  }

  Widget _identityCard(ProfileModel profile) {
    return CoachCard(
      padding: const EdgeInsets.all(CoachTokens.space5),
      child: Row(
        children: [
          CoachAvatar(
            initial: (profile.name ?? '?').trim().isEmpty
                ? '?'
                : profile.name!.trim().substring(0, 1).toUpperCase(),
            imageUrl: profile.imageUrl,
            radius: 30,
          ),
          const SizedBox(width: CoachTokens.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name ?? 'Coach',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: CoachTokens.textDark,
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
                      color: CoachTokens.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: CoachTokens.space2 + 2),
                CoachStatusChip(
                  label: profile.roleLabel,
                  color: CoachTokens.brand,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// What this coach is actually allowed to open, derived from the same
  /// permission set the menu is built from — so a coach can see why a section
  /// is missing without asking.
  Widget _accessCard() {
    final granted = CoachDestination.values
        .where((d) =>
            !d.alwaysShow &&
            PermissionService.instance.hasPermission(d.permission))
        .toList(growable: false);

    if (granted.isEmpty) return const SizedBox.shrink();

    return CoachCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What you can access',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: CoachTokens.textDark,
            ),
          ),
          const SizedBox(height: CoachTokens.space3),
          Wrap(
            spacing: CoachTokens.space2,
            runSpacing: CoachTokens.space2,
            children: granted
                .map(
                  (d) => CoachStatusChip(
                    label: d.label,
                    color: CoachTokens.info,
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
      padding: const EdgeInsets.all(CoachTokens.space4),
      decoration: BoxDecoration(
        color: CoachTokens.brandSoft,
        borderRadius: BorderRadius.circular(CoachTokens.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(
            Icons.info_outline_rounded,
            size: 19,
            color: CoachTokens.brand,
          ),
          SizedBox(width: CoachTokens.space3),
          Expanded(
            child: Text(
              'Your coach profile and the sections you can open are managed by '
              'an admin. Ask them to change anything here.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: CoachTokens.textBody,
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
          padding: const EdgeInsets.symmetric(vertical: CoachTokens.space3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: CoachTokens.textMuted),
              const SizedBox(width: CoachTokens.space3),
              SizedBox(
                width: 78,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: CoachTokens.textMuted,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: CoachTokens.textDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: CoachTokens.border),
      ],
    );
  }
}
