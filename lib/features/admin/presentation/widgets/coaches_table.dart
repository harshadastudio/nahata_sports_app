import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/coach.dart';
import '../../domain/entities/sport.dart';
import '../state/coaches_controller.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';

/// What a coach row can be asked to do.
enum CoachAction {
  view,
  edit,
  delete,
  viewPassword,
  resetPassword,
  setActive,
  setInactive,
}

/// The desktop/tablet table.
///
/// Same construction as the other console tables: a hand-built header/row pair
/// inside one horizontal scroll, so twelve columns never squeeze into
/// unreadable slivers.
class CoachesTable extends StatefulWidget {
  const CoachesTable({
    super.key,
    required this.coaches,
    required this.sort,
    required this.descending,
    required this.onSort,
    required this.onAction,
    required this.isBusy,
    this.selectedId,
  });

  final List<Coach> coaches;
  final CoachSort? sort;
  final bool descending;
  final ValueChanged<CoachSort> onSort;
  final void Function(CoachAction action, Coach coach) onAction;

  /// True while that row has a status write in flight.
  final bool Function(int id) isBusy;

  final int? selectedId;

  /// Twelve columns need real room; below this the table scrolls sideways.
  static const double _minWidth = 1760;

  @override
  State<CoachesTable> createState() => _CoachesTableState();
}

class _CoachesTableState extends State<CoachesTable> {
  /// Owned here rather than left to the PrimaryScrollController: a visible
  /// Scrollbar asserts without one, and the primary controller belongs to the
  /// vertical list this table sits inside.
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final overflows = constraints.maxWidth < CoachesTable._minWidth;
        final width = overflows ? CoachesTable._minWidth : constraints.maxWidth;

        return Scrollbar(
          controller: _horizontal,
          thumbVisibility: overflows,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderRow(
                    sort: widget.sort,
                    descending: widget.descending,
                    onSort: widget.onSort,
                  ),
                  ...widget.coaches.map(
                    (coach) => _Row(
                      key: ValueKey<int>(coach.id),
                      coach: coach,
                      selected: coach.id == widget.selectedId,
                      busy: widget.isBusy(coach.id),
                      onAction: widget.onAction,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Column layout shared by the header and every row.
class _Columns {
  const _Columns._();

  /// Fixed rather than flexed: an avatar has one right size.
  static const double image = 56;

  static const int name = 17;
  static const int email = 16;
  static const int phone = 11;
  static const int sport = 15;
  static const int complex = 13;
  static const int ground = 10;
  static const int experience = 10;
  static const int price = 9;
  static const int availability = 11;
  static const int status = 10;

  /// Wide enough for the View button plus the More menu at their real tap
  /// targets — a popup menu button will not shrink below 48.
  static const double actions = 100;
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.sort,
    required this.descending,
    required this.onSort,
  });

  final CoachSort? sort;
  final bool descending;
  final ValueChanged<CoachSort> onSort;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space5,
        vertical: AdminTokens.space3,
      ),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _Columns.image,
            child: Text(
              'Photo',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          _HeaderCell(
            label: 'Coach name',
            flex: _Columns.name,
            column: CoachSort.name,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Email',
            flex: _Columns.email,
            column: CoachSort.email,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(label: 'Phone', flex: _Columns.phone),
          _HeaderCell(
            label: 'Sport',
            flex: _Columns.sport,
            column: CoachSort.sport,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Sports complex',
            flex: _Columns.complex,
            column: CoachSort.complex,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Ground',
            flex: _Columns.ground,
            column: CoachSort.ground,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Experience',
            flex: _Columns.experience,
            column: CoachSort.experience,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Price',
            flex: _Columns.price,
            column: CoachSort.price,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Availability',
            flex: _Columns.availability,
            column: CoachSort.availability,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Status',
            flex: _Columns.status,
            column: CoachSort.status,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          const SizedBox(width: _Columns.actions),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatefulWidget {
  const _HeaderCell({
    required this.label,
    required this.flex,
    this.column,
    this.sort,
    this.descending = false,
    this.onSort,
  });

  final String label;
  final int flex;
  final CoachSort? column;
  final CoachSort? sort;
  final bool descending;
  final ValueChanged<CoachSort>? onSort;

  @override
  State<_HeaderCell> createState() => _HeaderCellState();
}

class _HeaderCellState extends State<_HeaderCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final sortable = widget.column != null && widget.onSort != null;
    final active = sortable && widget.sort == widget.column;

    final content = Row(
      children: [
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? tokens.accent : tokens.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (sortable)
          AnimatedOpacity(
            duration: AdminTokens.fast,
            opacity: active ? 1 : (_hovered ? 0.5 : 0),
            child: Icon(
              active && widget.descending
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 13,
              color: active ? tokens.accent : tokens.textMuted,
            ),
          ),
      ],
    );

    return Expanded(
      flex: widget.flex,
      child: Padding(
        padding: const EdgeInsets.only(right: AdminTokens.space3),
        child: sortable
            ? MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hovered = true),
                onExit: (_) => setState(() => _hovered = false),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onSort!(widget.column!),
                  child: content,
                ),
              )
            : content,
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({
    super.key,
    required this.coach,
    required this.selected,
    required this.busy,
    required this.onAction,
  });

  final Coach coach;
  final bool selected;
  final bool busy;
  final void Function(CoachAction action, Coach coach) onAction;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final coach = widget.coach;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onAction(CoachAction.view, coach),
        child: AnimatedContainer(
          duration: AdminTokens.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AdminTokens.space5,
            vertical: AdminTokens.space3,
          ),
          decoration: BoxDecoration(
            color: widget.selected
                ? tokens.accentSoft
                : (_hovered ? tokens.surfaceAlt : Colors.transparent),
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: _Columns.image,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: CoachAvatar(coach: coach, size: 40),
                ),
              ),
              Expanded(
                flex: _Columns.name,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        coach.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ((coach.specialization ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          coach.specialization!.trim(),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _TextCell(AdminFormat.text(coach.email), _Columns.email),
              _TextCell(AdminFormat.text(coach.phone), _Columns.phone),
              // The sport column carries both badges the spec asks for: the
              // primary sport, and the indoor/outdoor category beneath it.
              Expanded(
                flex: _Columns.sport,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CoachSportBadge(coach: coach),
                      if ((coach.categoryRaw ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        CoachCategoryChip(coach: coach),
                      ],
                    ],
                  ),
                ),
              ),
              _TextCell(
                AdminFormat.text(coach.sportComplexName),
                _Columns.complex,
                weight: FontWeight.w600,
              ),
              _TextCell(AdminFormat.text(coach.ground), _Columns.ground),
              _TextCell(
                AdminFormat.text(coach.experience),
                _Columns.experience,
              ),
              _TextCell(
                AdminFormat.currency(coach.price),
                _Columns.price,
                weight: FontWeight.w600,
              ),
              Expanded(
                flex: _Columns.availability,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AvailabilityChip(coach: coach),
                  ),
                ),
              ),
              Expanded(
                flex: _Columns.status,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: widget.busy
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : CoachStatusBadge(coach: coach, dense: true),
                  ),
                ),
              ),
              SizedBox(
                width: _Columns.actions,
                child: CoachRowActions(
                  coach: coach,
                  onAction: widget.onAction,
                  visible: _hovered || widget.selected,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextCell extends StatelessWidget {
  const _TextCell(this.value, this.flex, {this.weight = FontWeight.w400});

  final String value;
  final int flex;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: AdminTokens.space3),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: value == AdminFormat.dash
                  ? tokens.textMuted
                  : tokens.textSecondary,
              fontSize: 12.5,
              fontWeight: weight,
            ),
          ),
        ),
      ),
    );
  }
}

/// The coach photo, falling back to initials on a deterministic gradient — the
/// same treatment the other modules use, so a coach with no photo still reads
/// as a record rather than a hole in the table.
class CoachAvatar extends StatelessWidget {
  const CoachAvatar({super.key, required this.coach, this.size = 40});

  final Coach coach;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient('${coach.id}${coach.name ?? ''}');

    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        coach.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final url = coach.imageUrl;
    if (url == null) return fallback;

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        // A broken URL silently becomes initials — never a broken-image glyph.
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

/// The coach's primary sport.
class CoachSportBadge extends StatelessWidget {
  const CoachSportBadge({super.key, required this.coach, this.dense = true});

  final Coach coach;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final name = (coach.sportName ?? '').trim();

    if (name.isEmpty) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    final extra = coach.allSportNames.length - 1;

    final badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AdminTokens.space2 : AdminTokens.space3,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: tokens.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sports_tennis_rounded,
            size: dense ? 12 : 13,
            color: tokens.accent,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.accent,
                fontSize: dense ? 11 : 12,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
          // Only shown when the payload actually listed more sports.
          if (extra > 0) ...[
            const SizedBox(width: 4),
            Text(
              '+$extra',
              style: TextStyle(
                color: tokens.accent.withValues(alpha: 0.75),
                fontSize: dense ? 10 : 11,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ],
        ],
      ),
    );

    if (extra <= 0) return badge;

    return Tooltip(
      message: coach.allSportNames.join('\n'),
      waitDuration: const Duration(milliseconds: 300),
      child: badge,
    );
  }
}

/// Indoor / Outdoor, coloured so the two read apart at a glance. The category
/// belongs to the sport, so it is absent whenever the payload did not carry it.
class CoachCategoryChip extends StatelessWidget {
  const CoachCategoryChip({super.key, required this.coach, this.dense = true});

  final Coach coach;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final raw = (coach.categoryRaw ?? '').trim();

    if (raw.isEmpty) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    final indoor = coach.category == SportCategory.indoor;
    final color = switch (coach.category) {
      SportCategory.indoor => const Color(0xFF8B5CF6),
      SportCategory.outdoor => tokens.success,
      null => tokens.textMuted,
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AdminTokens.space2 : AdminTokens.space3,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            indoor ? Icons.home_work_outlined : Icons.park_outlined,
            size: dense ? 12 : 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              coach.categoryLabel,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: dense ? 11 : 12,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The availability summary, with the full schedule behind a tooltip.
///
/// A schedule the app can read shows its day count and turns green when today
/// is one of them; a free-text schedule is shown as written, in neutral
/// colours, because nothing here can honestly say whether it covers today.
class AvailabilityChip extends StatelessWidget {
  const AvailabilityChip({super.key, required this.coach, this.now});

  final Coach coach;

  /// Injectable so a test can pin "today".
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final availability = coach.availability;

    if (availability.isEmpty) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    final today = availability.availableOn(now ?? DateTime.now());
    final color = switch (today) {
      true => tokens.success,
      false => tokens.textMuted,
      null => tokens.info,
    };

    final chip = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            today == true
                ? Icons.event_available_rounded
                : Icons.calendar_month_outlined,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              availability.summaryLabel,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );

    return Tooltip(
      message: availability.isCustom
          ? availability.raw
          : [
              availability.days.map((day) => day.label).join(', '),
              if (today == true) 'Available today',
            ].join('\n'),
      waitDuration: const Duration(milliseconds: 300),
      child: chip,
    );
  }
}

class CoachStatusBadge extends StatelessWidget {
  const CoachStatusBadge({super.key, required this.coach, this.dense = false});

  final Coach coach;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final color = tokens.statusColor(coach.status);
    final label = coach.statusLabel.isEmpty
        ? AdminFormat.dash
        : coach.statusLabel;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AdminTokens.space2 : AdminTokens.space3,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AdminTokens.space2),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: dense ? 11 : 12,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// View / Edit / Delete, plus the credential and status items behind "More".
class CoachRowActions extends StatelessWidget {
  const CoachRowActions({
    super.key,
    required this.coach,
    required this.onAction,
    required this.visible,
  });

  final Coach coach;
  final void Function(CoachAction action, Coach coach) onAction;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final isActive = coach.isActive;

    return AnimatedOpacity(
      // Always in the tree so the row height is stable and the menus stay
      // reachable where hover does not exist.
      duration: AdminTokens.fast,
      opacity: visible ? 1 : 0.35,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => onAction(CoachAction.view, coach),
            icon: const Icon(Icons.visibility_outlined, size: 17),
            tooltip: 'View details',
            color: tokens.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          ),
          PopupMenuButton<CoachAction>(
            tooltip: 'More actions',
            icon: Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: tokens.textMuted,
            ),
            padding: EdgeInsets.zero,
            onSelected: (action) => onAction(action, coach),
            itemBuilder: (context) => [
              _item(
                CoachAction.edit,
                Icons.edit_outlined,
                'Edit coach',
                tokens.textPrimary,
              ),
              const PopupMenuDivider(),
              _item(
                CoachAction.viewPassword,
                Icons.key_outlined,
                'View password',
                tokens.textPrimary,
              ),
              _item(
                CoachAction.resetPassword,
                Icons.lock_reset_rounded,
                'Reset password',
                tokens.textPrimary,
              ),
              const PopupMenuDivider(),
              // Only the status it is not already in is offered, so the menu
              // never presents a no-op.
              if (!isActive)
                _item(
                  CoachAction.setActive,
                  Icons.check_circle_outline_rounded,
                  'Mark as Active',
                  tokens.success,
                ),
              if (isActive)
                _item(
                  CoachAction.setInactive,
                  Icons.pause_circle_outline_rounded,
                  'Mark as Inactive',
                  tokens.warning,
                ),
              const PopupMenuDivider(),
              _item(
                CoachAction.delete,
                Icons.delete_outline_rounded,
                'Delete coach',
                tokens.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<CoachAction> _item(
    CoachAction value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<CoachAction>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: AdminTokens.space3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// The mobile equivalent of a table row.
class CoachCard extends StatelessWidget {
  const CoachCard({
    super.key,
    required this.coach,
    required this.busy,
    required this.onAction,
  });

  final Coach coach;
  final bool busy;
  final void Function(CoachAction action, Coach coach) onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return InkWell(
      onTap: () => onAction(CoachAction.view, coach),
      child: Container(
        padding: const EdgeInsets.all(AdminTokens.space4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoachAvatar(coach: coach, size: 46),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        coach.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AdminFormat.text(coach.email),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                CoachRowActions(
                  coach: coach,
                  onAction: onAction,
                  visible: true,
                ),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Wrap(
              spacing: AdminTokens.space2,
              runSpacing: AdminTokens.space2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  CoachStatusBadge(coach: coach, dense: true),
                CoachSportBadge(coach: coach),
                if ((coach.categoryRaw ?? '').trim().isNotEmpty)
                  CoachCategoryChip(coach: coach),
                AvailabilityChip(coach: coach),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Complex',
                    value: AdminFormat.text(coach.sportComplexName),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Ground',
                    value: AdminFormat.text(coach.ground),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Experience',
                    value: AdminFormat.text(coach.experience),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Price',
                    value: AdminFormat.currency(coach.price),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Phone',
                    value: AdminFormat.text(coach.phone),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: tokens.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
