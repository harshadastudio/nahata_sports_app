import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/admin_sports_complex.dart';
import '../state/view_state.dart';
import '../navigation/admin_module.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'admin_states.dart';
import 'glass_card.dart';
import 'sports_complexes_table.dart';

/// The right-side sports complex detail panel.
///
/// Shows the row already in hand immediately, then fills in from
/// `GET /sports-complexes/{id}` and `/{id}/stats` behind a thin progress line.
/// The two reads are tracked separately: a stats failure leaves a note in the
/// Operations card rather than blanking a drawer whose detail arrived fine.
class SportsComplexDetailPanel extends StatelessWidget {
  const SportsComplexDetailPanel({
    super.key,
    required this.complex,
    required this.state,
    required this.error,
    required this.stats,
    required this.statsState,
    required this.onClose,
    required this.onAction,
    required this.onRetry,
    required this.onRetryStats,
    required this.onToggleVisibility,
    required this.busy,
    this.showCloseButton = true,
  });

  final AdminSportsComplex complex;
  final ViewState state;
  final String? error;
  final SportsComplexStats? stats;
  final ViewState statsState;
  final VoidCallback onClose;
  final void Function(SportsComplexAction action, AdminSportsComplex complex)
  onAction;
  final VoidCallback onRetry;
  final VoidCallback onRetryStats;
  final void Function(AdminSportsComplex complex, bool showOnFrontend)
  onToggleVisibility;
  final bool busy;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(
            AdminTokens.space5,
            AdminTokens.space4,
            AdminTokens.space3,
            AdminTokens.space4,
          ),
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Sports complex details',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (showCloseButton)
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Close',
                  color: tokens.textMuted,
                ),
            ],
          ),
        ),
        RefreshLine(visible: state.isLoading),
        Expanded(
          child: state.isFailed
              ? ErrorStateView(
                  compact: true,
                  title: 'Could not load this sports complex',
                  message: error ?? 'Please try again.',
                  onRetry: onRetry,
                )
              : ListView(
                  padding: const EdgeInsets.all(AdminTokens.space5),
                  children: [
                    _HeroCard(
                      complex: complex,
                      busy: busy,
                      onToggleVisibility: onToggleVisibility,
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    _Card(
                      icon: Icons.place_outlined,
                      title: 'Address information',
                      rows: [
                        _Row('Address', AdminFormat.text(complex.address)),
                        _Row('City', AdminFormat.text(complex.city)),
                        _Row('State', AdminFormat.text(complex.state)),
                        _Row('Zip code', AdminFormat.text(complex.zipCode)),
                      ],
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    _Card(
                      icon: Icons.call_outlined,
                      title: 'Contact information',
                      rows: [
                        _Row(
                          'Contact phone',
                          AdminFormat.text(complex.contactPhone),
                          copyable: true,
                        ),
                        _Row(
                          'Contact email',
                          AdminFormat.text(complex.contactEmail),
                          copyable: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    _OperationsCard(
                      complex: complex,
                      stats: stats,
                      statsState: statsState,
                      onRetryStats: onRetryStats,
                    ),
                    if (complex.facilityList.isNotEmpty) ...[
                      const SizedBox(height: AdminTokens.space4),
                      _FacilitiesCard(complex: complex),
                    ],
                    const SizedBox(height: AdminTokens.space4),
                    _LocationCard(complex: complex),
                    if (complex.hasIntegrationIds) ...[
                      const SizedBox(height: AdminTokens.space4),
                      _IntegrationsCard(complex: complex),
                    ],
                    const SizedBox(height: AdminTokens.space6),
                  ],
                ),
        ),
        Container(
          padding: const EdgeInsets.all(AdminTokens.space4),
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border(top: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              if (AdminAccess.canDelete(AdminModules.sportsComplex))
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        onAction(SportsComplexAction.delete, complex),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.danger,
                      side: BorderSide(
                        color: tokens.danger.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: AdminTokens.space3),
              if (AdminAccess.canEdit(AdminModules.sportsComplex))
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => onAction(SportsComplexAction.edit, complex),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit complex'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Basic information: the photo, the name, and the two state controls.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.complex,
    required this.busy,
    required this.onToggleVisibility,
  });

  final AdminSportsComplex complex;
  final bool busy;
  final void Function(AdminSportsComplex complex, bool showOnFrontend)
  onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final url = complex.imageUrl;

    return SolidCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AdminTokens.radiusLg),
            ),
            child: SizedBox(
              height: 150,
              child: url == null
                  ? _ImageFallback(complex: complex)
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _ImageFallback(complex: complex),
                      errorWidget: (_, __, ___) =>
                          _ImageFallback(complex: complex),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AdminTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  complex.displayName,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if ((complex.city ?? '').trim().isNotEmpty)
                      complex.city!.trim(),
                    if ((complex.state ?? '').trim().isNotEmpty)
                      complex.state!.trim(),
                  ].join(', '),
                  style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
                ),
                const SizedBox(height: AdminTokens.space4),
                Row(
                  children: [
                    ComplexStatusBadge(complex: complex),
                    const Spacer(),
                    Text(
                      'Show on frontend',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AdminTokens.space2),
                    FrontendVisibilitySwitch(
                      complex: complex,
                      busy: busy,
                      showLabel: false,
                      onChanged: (value) => onToggleVisibility(complex, value),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.complex});

  final AdminSportsComplex complex;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient('${complex.id}${complex.name ?? ''}');

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.stadium_outlined,
        size: 40,
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );
  }
}

/// Opening hours, manager, and the two court counters from the stats route.
class _OperationsCard extends StatelessWidget {
  const _OperationsCard({
    required this.complex,
    required this.stats,
    required this.statsState,
    required this.onRetryStats,
  });

  final AdminSportsComplex complex;
  final SportsComplexStats? stats;
  final ViewState statsState;
  final VoidCallback onRetryStats;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    // The stats route is authoritative for the counters; the list row's own
    // numbers are the fallback when it has not answered.
    final totalCourts = stats?.totalCourts ?? complex.totalCourts;
    final activeCourts = stats?.activeCourts ?? complex.activeCourts;

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 17,
                color: tokens.accent,
              ),
              const SizedBox(width: AdminTokens.space2),
              Expanded(
                child: Text(
                  'Operations',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (statsState.isLoading)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (statsState.isFailed)
                TextButton(
                  onPressed: onRetryStats,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Retry stats',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          _Row('Opening hours', AdminFormat.text(complex.openingHours)),
          _Row('Manager', AdminFormat.text(complex.managerName)),
          const SizedBox(height: AdminTokens.space3),
          Row(
            children: [
              Expanded(
                child: _Counter(
                  label: 'Total courts',
                  value: totalCourts,
                  icon: Icons.grid_view_rounded,
                  color: tokens.info,
                ),
              ),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                child: _Counter(
                  label: 'Active courts',
                  value: activeCourts,
                  icon: Icons.check_circle_outline_rounded,
                  color: tokens.success,
                ),
              ),
            ],
          ),
          // Anything else the stats route sent, shown only when it did.
          if (stats != null) ...[
            if (stats!.totalSports != null ||
                stats!.totalBookings != null ||
                stats!.totalStaff != null) ...[
              const SizedBox(height: AdminTokens.space3),
              Wrap(
                spacing: AdminTokens.space3,
                runSpacing: AdminTokens.space3,
                children: [
                  if (stats!.totalSports != null)
                    _Pill(
                      label: 'Sports',
                      value: stats!.totalSports!,
                      icon: Icons.sports_tennis_rounded,
                    ),
                  if (stats!.totalBookings != null)
                    _Pill(
                      label: 'Bookings',
                      value: stats!.totalBookings!,
                      icon: Icons.event_available_rounded,
                    ),
                  if (stats!.totalStaff != null)
                    _Pill(
                      label: 'Staff',
                      value: stats!.totalStaff!,
                      icon: Icons.badge_outlined,
                    ),
                ],
              ),
            ],
          ],
          if (statsState.isFailed) ...[
            const SizedBox(height: AdminTokens.space3),
            Text(
              'Court statistics are unavailable right now — the figures above '
              'come from the complex record itself.',
              style: TextStyle(
                color: tokens.textMuted,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int? value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: AdminTokens.space2),
          Text(
            // A missing counter reads as an em dash, never as zero.
            AdminFormat.number(value),
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value, required this.icon});

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space3,
        vertical: AdminTokens.space2,
      ),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tokens.textMuted),
          const SizedBox(width: 5),
          Text(
            '${AdminFormat.number(value)} $label',
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FacilitiesCard extends StatelessWidget {
  const _FacilitiesCard({required this.complex});

  final AdminSportsComplex complex;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pool_outlined, size: 17, color: tokens.accent),
              const SizedBox(width: AdminTokens.space2),
              Text(
                'Facilities',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          Wrap(
            spacing: AdminTokens.space2,
            runSpacing: AdminTokens.space2,
            children: complex.facilityList
                .map(
                  (facility) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AdminTokens.space3,
                      vertical: AdminTokens.space2,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.accentSoft,
                      borderRadius: BorderRadius.circular(
                        AdminTokens.radiusPill,
                      ),
                    ),
                    child: Text(
                      facility,
                      style: TextStyle(
                        color: tokens.accent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.complex});

  final AdminSportsComplex complex;

  Future<void> _openMaps(BuildContext context) async {
    final link = complex.mapsLink;
    if (link == null) return;

    final uri = Uri.tryParse(link);
    if (uri == null) return;

    AdminLog.ui('Opening maps for complex ${complex.id}');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (opened || !context.mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Could not open Maps.')));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final link = complex.mapsLink;

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.map_outlined, size: 17, color: tokens.accent),
              const SizedBox(width: AdminTokens.space2),
              Text(
                'Location',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          _Row('Google map URL', AdminFormat.text(complex.mapUrl)),
          _Row(
            'Latitude',
            complex.latitude == null ? AdminFormat.dash : '${complex.latitude}',
          ),
          _Row(
            'Longitude',
            complex.longitude == null
                ? AdminFormat.dash
                : '${complex.longitude}',
          ),
          const SizedBox(height: AdminTokens.space3),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              // Enabled whenever there is anything to point at — a stored URL,
              // coordinates, or an address worth searching for.
              onPressed: link == null ? null : () => _openMaps(context),
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: const Text('Open in Maps'),
            ),
          ),
          if (link == null) ...[
            const SizedBox(height: AdminTokens.space2),
            Text(
              'No map URL, coordinates or address on file.',
              style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// The external system ids, collapsed by default — they matter to an
/// integrator, not to someone checking a venue's phone number.
class _IntegrationsCard extends StatefulWidget {
  const _IntegrationsCard({required this.complex});

  final AdminSportsComplex complex;

  @override
  State<_IntegrationsCard> createState() => _IntegrationsCardState();
}

class _IntegrationsCardState extends State<_IntegrationsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final complex = widget.complex;

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
            child: Row(
              children: [
                Icon(Icons.hub_outlined, size: 17, color: tokens.accent),
                const SizedBox(width: AdminTokens.space2),
                Expanded(
                  child: Text(
                    'Integrations',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: AdminTokens.fast,
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: tokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: AdminTokens.normal,
            sizeCurve: AdminTokens.curve,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: AdminTokens.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Row(
                    'External org ID',
                    AdminFormat.text(complex.externalOrgId),
                    copyable: true,
                  ),
                  _Row(
                    'External site ID',
                    AdminFormat.text(complex.externalSiteId),
                    copyable: true,
                  ),
                  _Row(
                    'External UUID',
                    AdminFormat.text(complex.externalUuid),
                    copyable: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.title, this.rows = const []});

  final IconData icon;
  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: tokens.accent),
              const SizedBox(width: AdminTokens.space2),
              Text(
                title,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: AdminTokens.space3),
            ...rows,
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.copyable = false});

  final String label;
  final String value;

  /// Adds a copy button — used for the values an admin actually pastes
  /// elsewhere (contact details and external ids).
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final missing = value == AdminFormat.dash;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: missing ? tokens.textMuted : tokens.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (copyable && !missing)
            InkWell(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (!context.mounted) return;
                ScaffoldMessenger.maybeOf(context)
                  ?..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text('$label copied')));
              },
              borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(
                  Icons.copy_rounded,
                  size: 14,
                  color: tokens.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
