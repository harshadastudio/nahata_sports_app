import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_formats.dart';
import '../../domain/entities/employee_master.dart';
import '../state/employee_blocked_slots_controller.dart';
import '../state/employee_view_state.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_forms.dart';
import '../widgets/employee_stat_tile.dart';
import '../widgets/employee_states.dart';

/// Blocked Slots — close a court for a date.
///
/// A grid rather than a list: an employee scanning for "which hours are free
/// this afternoon" reads a grid far faster, and the whole day fits on one
/// screen.
class EmployeeBlockedSlotsPage extends StatefulWidget {
  const EmployeeBlockedSlotsPage({super.key});

  @override
  State<EmployeeBlockedSlotsPage> createState() =>
      _EmployeeBlockedSlotsPageState();
}

class _EmployeeBlockedSlotsPageState extends State<EmployeeBlockedSlotsPage> {
  late final EmployeeBlockedSlotsController _controller =
      EmployeeBlockedSlotsController(EmployeeDashboardRepositoryImpl());

  @override
  void initState() {
    super.initState();
    _controller.loadCourts();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EmployeeTokens.canvas,
      appBar: AppBar(
        backgroundColor: EmployeeTokens.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        // Clamped so the two stacked lines cannot overrun the 56dp toolbar at
        // large accessibility text sizes.
        title: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Blocked slots',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                if (_controller.fetched)
                  Text(
                    '${_controller.blockedCount} of ${_controller.slots.length} '
                    'blocked',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.white70,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _controller.fetched ? _controller.fetchSlots : null,
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(
            EmployeeTokens.space4,
            EmployeeTokens.space4,
            EmployeeTokens.space4,
            EmployeeTokens.space8,
          ),
          children: [
            const EmployeeScopeNotice(
              message: 'Blocks apply to the selected date only. To close a '
                  'time on every date, deactivate the slot on the Slots '
                  'screen.',
            ),
            const SizedBox(height: EmployeeTokens.space4),
            _selector(),
            const SizedBox(height: EmployeeTokens.space4),
            ..._body(),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Selector
  // ───────────────────────────────────────────────────────────────────────────

  Widget _selector() {
    final courts = _controller.courts;

    return EmployeeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmployeeField(
            label: 'Court',
            child: EmployeeDropdown<int>(
              value: _controller.court?.id,
              items: courts.map((c) => c.id).toList(),
              labelOf: (id) => courts.firstWhere((c) => c.id == id).displayName,
              subtitleOf: (id) {
                final court = courts.firstWhere((c) => c.id == id);
                return court.sportName.isEmpty ? null : court.sportName;
              },
              placeholder: courts.isEmpty ? 'No courts yet' : 'Select a court',
              onChanged: (value) {
                if (value == null) return;
                _controller.selectCourt(
                  courts.firstWhere((c) => c.id == value),
                );
              },
            ),
          ),
          EmployeeField(
            label: 'Date',
            child: EmployeeDateField(
              value: _controller.date,
              clearable: false,
              // A block on a past date is meaningless, so the picker starts
              // today.
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              onChanged: (value) {
                if (value != null) _controller.selectDate(value);
              },
            ),
          ),
          FilledButton.icon(
            onPressed: _controller.canFetch && !_controller.state.isLoading
                ? _controller.fetchSlots
                : null,
            icon: _controller.state.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.search_rounded, size: 18),
            label: const Text('Fetch time slots'),
            style: FilledButton.styleFrom(
              backgroundColor: EmployeeTokens.brand,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Body
  // ───────────────────────────────────────────────────────────────────────────

  List<Widget> _body() {
    if (_controller.state.isFailed) {
      return [
        EmployeeCard(
          child: EmployeeErrorView(
            compact: true,
            message: _controller.error ?? 'That did not load.',
            onRetry: _controller.fetched
                ? _controller.fetchSlots
                : () => _controller.loadCourts(),
          ),
        ),
      ];
    }

    if (_controller.courts.isEmpty && !_controller.state.isLoading) {
      return const [
        EmployeeCard(
          child: EmployeeEmptyView(
            compact: true,
            icon: Icons.place_outlined,
            title: 'No courts yet',
            message: 'Add a court on the Courts screen, then come back to '
                'manage its availability.',
          ),
        ),
      ];
    }

    if (!_controller.fetched) {
      return const [
        EmployeeCard(
          child: EmployeeEmptyView(
            compact: true,
            icon: Icons.event_available_outlined,
            title: 'Pick a court and date',
            message: 'Then fetch the time slots to open or close them for '
                'that day.',
          ),
        ),
      ];
    }

    if (_controller.slots.isEmpty) {
      return const [
        EmployeeCard(
          child: EmployeeEmptyView(
            compact: true,
            icon: Icons.schedule_outlined,
            title: 'No slots on this court',
            message: 'Add bookable times on the Slots screen first.',
          ),
        ),
      ];
    }

    final visible = _controller.visibleSlots;

    return [
      _toolbar(),
      const SizedBox(height: EmployeeTokens.space4),
      if (visible.isEmpty)
        EmployeeCard(
          child: EmployeeEmptyView(
            compact: true,
            icon: Icons.filter_alt_off_rounded,
            title: 'Nothing to show',
            message: 'No ${_controller.filter.label.toLowerCase()} slots for '
                'this court and date.',
          ),
        )
      else
        EmployeeTileGrid(
          children: [for (final slot in visible) _slotTile(slot)],
        ),
      const SizedBox(height: EmployeeTokens.space4),
      _legend(),
    ];
  }

  Widget _toolbar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Height follows the text rather than a fixed box — see
        // [EmployeeFilterChips] for the same reasoning.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in EmployeeSlotFilter.values) ...[
                if (filter != EmployeeSlotFilter.values.first)
                  const SizedBox(width: EmployeeTokens.space2),
                _filterChip(filter),
              ],
            ],
          ),
        ),
        const SizedBox(height: EmployeeTokens.space3),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _controller.busy ? null : () => _bulk(block: true),
                icon: const Icon(Icons.lock_outline_rounded, size: 16),
                label: const Text(
                  'Block all',
                  style: TextStyle(fontSize: 12.5),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: EmployeeTokens.danger,
                  side: BorderSide(
                    color: EmployeeTokens.danger.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: EmployeeTokens.space3,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(EmployeeTokens.radiusSm),
                  ),
                ),
              ),
            ),
            const SizedBox(width: EmployeeTokens.space3),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _controller.busy ? null : () => _bulk(block: false),
                icon: const Icon(Icons.lock_open_rounded, size: 16),
                label: const Text(
                  'Unblock all',
                  style: TextStyle(fontSize: 12.5),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: EmployeeTokens.success,
                  side: BorderSide(
                    color: EmployeeTokens.success.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: EmployeeTokens.space3,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(EmployeeTokens.radiusSm),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _filterChip(EmployeeSlotFilter filter) {
    final active = filter == _controller.filter;

    return Material(
      color: active ? EmployeeTokens.brand : EmployeeTokens.surface,
      borderRadius: BorderRadius.circular(EmployeeTokens.radiusPill),
      child: InkWell(
        onTap: () => _controller.setFilter(filter),
        borderRadius: BorderRadius.circular(EmployeeTokens.radiusPill),
        child: Container(
          // Same floor-not-fixed-height reasoning as [EmployeeFilterChips].
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(
            horizontal: EmployeeTokens.space4,
            vertical: EmployeeTokens.space2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(EmployeeTokens.radiusPill),
            border: Border.all(
              color: active ? EmployeeTokens.brand : EmployeeTokens.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            filter.label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : EmployeeTokens.textBody,
            ),
          ),
        ),
      ),
    );
  }

  Widget _slotTile(EmployeeAvailableSlot slot) {
    final byCustomer = slot.isUserBooked;
    final byPartner = slot.isPartnerBlock;
    final blocked = slot.isBlocked;
    final busy = _controller.busySlotId == slot.id;

    final (background, borderColor, tone, icon) = switch (true) {
      _ when byCustomer => (
          EmployeeTokens.purple.withValues(alpha: 0.08),
          EmployeeTokens.purple.withValues(alpha: 0.3),
          EmployeeTokens.purple,
          Icons.person_rounded,
        ),
      _ when byPartner => (
          EmployeeTokens.warning.withValues(alpha: 0.09),
          EmployeeTokens.warning.withValues(alpha: 0.35),
          EmployeeTokens.warning,
          Icons.public_rounded,
        ),
      _ when blocked => (
          EmployeeTokens.danger.withValues(alpha: 0.07),
          EmployeeTokens.danger.withValues(alpha: 0.3),
          EmployeeTokens.danger,
          Icons.lock_rounded,
        ),
      _ => (
          EmployeeTokens.surface,
          EmployeeTokens.border,
          EmployeeTokens.success,
          Icons.lock_open_rounded,
        ),
    };

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(EmployeeTokens.radiusMd),
      child: InkWell(
        onTap: byCustomer || busy ? null : () => _toggle(slot),
        borderRadius: BorderRadius.circular(EmployeeTokens.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(EmployeeTokens.space3 + 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(EmployeeTokens.radiusMd),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      slot.timeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: EmployeeTokens.textDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: EmployeeTokens.space1),
                  if (busy)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: EmployeeTokens.textMuted,
                      ),
                    )
                  else
                    Icon(icon, size: 15, color: tone),
                ],
              ),
              const SizedBox(height: EmployeeTokens.space2),
              Text(
                slot.stateLabel.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                  color: tone,
                ),
              ),
              if (slot.isRecurringBlock) ...[
                const SizedBox(height: 3),
                const Row(
                  children: [
                    Icon(
                      Icons.repeat_rounded,
                      size: 10,
                      color: EmployeeTokens.warning,
                    ),
                    SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        'Every date',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: EmployeeTokens.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const Spacer(),
              Text(
                byCustomer
                    ? 'Cancel the booking to free it'
                    : 'Tap to ${blocked ? 'unblock' : 'block'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.3,
                  color: EmployeeTokens.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legend() {
    return EmployeeCard(
      padding: const EdgeInsets.all(EmployeeTokens.space3),
      child: Wrap(
        spacing: EmployeeTokens.space3,
        runSpacing: EmployeeTokens.space2,
        children: const [
          _LegendDot(color: EmployeeTokens.success, label: 'Available'),
          _LegendDot(color: EmployeeTokens.danger, label: 'Blocked by you'),
          _LegendDot(color: EmployeeTokens.warning, label: 'Partner hold'),
          _LegendDot(color: EmployeeTokens.purple, label: 'Customer booking'),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Actions
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _toggle(EmployeeAvailableSlot slot) async {
    // A recurring block reopens every date, so it is confirmed before it goes
    // out — the tile says so, but this is not undoable.
    if (slot.isBlocked && slot.isRecurringBlock) {
      final ok = await confirmEmployeeAction(
        context,
        title: 'This is a recurring block',
        message: 'It applies to every date, not just '
            '${formatDay(_controller.date)}. Unblocking reopens this time on '
            'all dates. Continue?',
        confirmLabel: 'Unblock everywhere',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }

    final wasBlocked = slot.isBlocked;
    final error = await _controller.toggle(slot);
    if (!mounted) return;

    showEmployeeToast(
      context,
      error ?? (wasBlocked ? 'Slot unblocked' : 'Slot blocked'),
      isError: error != null,
    );
  }

  Future<void> _bulk({required bool block}) async {
    final targets = _controller.bulkTargets(block: block);

    if (targets.isEmpty) {
      showEmployeeToast(
        context,
        block ? 'Every slot is already blocked.' : 'Every slot is already open.',
      );
      return;
    }

    final recurring =
        block ? 0 : _controller.recurringAmong(targets);
    final warning = recurring == 0
        ? ''
        : '\n\n$recurring of them are recurring blocks — unblocking those '
            'reopens the time on EVERY date.';

    final ok = await confirmEmployeeAction(
      context,
      title: '${block ? 'Block' : 'Unblock'} ${targets.length} slot'
          '${targets.length == 1 ? '' : 's'}?',
      message: 'For ${formatDay(_controller.date)} on '
          '${_controller.court?.displayName ?? 'this court'}. '
          'Customer bookings are left alone.$warning',
      confirmLabel: block ? 'Block them' : 'Unblock them',
      destructive: block,
    );
    if (!ok || !mounted) return;

    final result = await _controller.bulkSet(block: block);
    if (!mounted) return;

    if (result.nothingToDo) {
      showEmployeeToast(context, 'Nothing needed changing.');
      return;
    }

    showEmployeeToast(
      context,
      result.isComplete
          ? '${result.succeeded} slot${result.succeeded == 1 ? '' : 's'} '
              '${block ? 'blocked' : 'unblocked'}'
          // A partial result is reported honestly — the grid above already
          // shows which ones actually moved.
          : '${result.succeeded} of ${result.attempted} updated — check the '
              'grid above',
      isError: !result.isComplete,
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: EmployeeTokens.textBody,
          ),
        ),
      ],
    );
  }
}
