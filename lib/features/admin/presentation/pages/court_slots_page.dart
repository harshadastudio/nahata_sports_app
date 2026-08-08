import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/court.dart';
import '../../domain/entities/court_slot.dart';
import '../../domain/repositories/court_slot_repository.dart';
import '../navigation/admin_module.dart';
import '../state/court_slots_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/admin_states.dart';
import '../widgets/availability_calendar.dart';
import '../widgets/glass_card.dart';
import '../widgets/slot_form_dialog.dart';
import '../widgets/slots_table.dart';
import '../widgets/stat_card.dart';

/// Manage Slots — one court's whole schedule.
///
/// A screen rather than a drawer: it owns three views and its own writes, and
/// the spec asks for it to be reachable as a destination from a court row.
class CourtSlotsPage extends StatelessWidget {
  const CourtSlotsPage({
    super.key,
    required this.court,
    required this.repository,
  });

  final Court court;
  final CourtSlotRepository repository;

  /// Pushes the screen, scoping a controller to it so the schedule is dropped
  /// when the admin leaves rather than kept alive behind the court list.
  static Future<void> open(
    BuildContext context, {
    required Court court,
    required CourtSlotRepository repository,
  }) {
    AdminLog.ui('Manage slots opened for court ${court.id}');
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourtSlotsPage(court: court, repository: repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CourtSlotsController>(
      create: (_) => CourtSlotsController(repository, court)..load(),
      child: const _SlotsScaffold(),
    );
  }
}

class _SlotsScaffold extends StatelessWidget {
  const _SlotsScaffold();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CourtSlotsController>();
    final tokens = AdminTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < AdminTokens.mobileMax;

    final body = switch (controller.view) {
      SlotsView.schedule => _ScheduleView(
        controller: controller,
        isMobile: isMobile,
      ),
      SlotsView.day => DayAvailabilityView(
        controller: controller,
        onPickDate: () => _pickDate(context, controller),
      ),
      SlotsView.week => WeekAvailabilityCalendar(controller: controller),
    };

    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: AppBar(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        shape: Border(bottom: BorderSide(color: tokens.border)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              controller.court.displayName,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              [
                controller.court.sportName,
                controller.court.sportComplexName,
              ].whereType<String>().where((part) => part.isNotEmpty).join(' · '),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: controller.state.isLoading ? null : controller.refresh,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh',
            color: tokens.textSecondary,
          ),
          // Slots belong to the Courts module, so `permissions.courts.create`
          // decides whether a slot can be added. This screen is pushed from
          // Courts, which a COMPLEX_ADMIN does reach — without the gate a venue
          // admin granted view-only would be offered a button the API refuses.
          if (AdminAccess.canCreate(AdminModules.courts))
            Padding(
              padding: const EdgeInsets.only(right: AdminTokens.space4),
              child: FilledButton.icon(
                onPressed: () => _openForm(context, controller),
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('Add Slot'),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(
            isMobile ? AdminTokens.space4 : AdminTokens.space6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ViewSwitcher(controller: controller),
              const SizedBox(height: AdminTokens.space4),
              if (controller.view == SlotsView.schedule) ...[
                _SummaryCards(controller: controller),
                const SizedBox(height: AdminTokens.space4),
              ],
              Expanded(
                child: SolidCard(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        RefreshLine(visible: controller.isRefreshing),
                        Expanded(child: body),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

Future<void> _pickDate(
  BuildContext context,
  CourtSlotsController controller,
) async {
  final now = DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: controller.selectedDate,
    // A year either side: availability is only meaningful near today, but an
    // admin checking a season ahead is legitimate.
    firstDate: DateTime(now.year - 1),
    lastDate: DateTime(now.year + 1),
    helpText: 'Select a date',
  );

  if (picked == null) return;
  controller.setDate(picked);
}

Future<void> _openForm(
  BuildContext context,
  CourtSlotsController controller, {
  CourtSlot? slot,
}) async {
  final saved = await SlotFormDialog.show(
    context,
    slot: slot,
    findClashes: (draft) => controller.clashesWith(draft, ignoreId: slot?.id),
    onSubmit: (draft) async {
      if (slot == null) {
        await controller.create(draft);
      } else {
        await controller.update(slot.id, draft);
      }
    },
  );

  if (!saved || !context.mounted) return;

  AdminFeedback.success(
    context,
    slot == null ? 'Slot created.' : 'Changes to this slot were saved.',
  );
}

// -----------------------------------------------------------------------------
// Schedule
// -----------------------------------------------------------------------------

class _ScheduleView extends StatelessWidget {
  const _ScheduleView({required this.controller, required this.isMobile});

  final CourtSlotsController controller;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    if (controller.isFirstLoad) {
      return const SingleChildScrollView(child: TableShimmer(rows: 6));
    }

    if (controller.state.isFailed) {
      return ErrorStateView(
        title: 'Could not load slots',
        message:
            controller.error ??
            'The server did not return the slots for this court.',
        onRetry: controller.refresh,
      );
    }

    final slots = controller.orderedSlots;

    if (slots.isEmpty) {
      return EmptyStateView(
        icon: Icons.event_busy_outlined,
        title: 'No slots available',
        message:
            'This court has no bookable windows yet. Add the first one to '
            'open it for booking.',
        actionLabel: 'Add Slot',
        onAction: () => _openForm(context, controller),
        secondaryLabel: 'Refresh',
        onSecondary: controller.refresh,
      );
    }

    if (isMobile) {
      return ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: slots.length,
        itemBuilder: (context, index) {
          final slot = slots[index];
          return SlotCard(
            slot: slot,
            court: controller.court,
            busy: controller.isRowBusy(slot.id),
            onAction: (action, target) => _handle(context, action, target),
            onToggle: (target) => _toggle(context, target),
          );
        },
      );
    }

    return SingleChildScrollView(
      child: SlotsTable(
        slots: slots,
        court: controller.court,
        isBusy: controller.isRowBusy,
        onAction: (action, slot) => _handle(context, action, slot),
        onToggle: (slot) => _toggle(context, slot),
      ),
    );
  }

  Future<void> _handle(
    BuildContext context,
    SlotAction action,
    CourtSlot slot,
  ) async {
    switch (action) {
      case SlotAction.edit:
        await _openForm(context, controller, slot: slot);
      case SlotAction.delete:
        await _confirmDelete(context, slot);
    }
  }

  Future<void> _toggle(BuildContext context, CourtSlot slot) async {
    try {
      await controller.toggle(slot.id);
      if (!context.mounted) return;
      // Read back off the row: the server may have settled somewhere other
      // than the optimistic guess.
      final settled = controller.slots
          .where((candidate) => candidate.id == slot.id)
          .firstOrNull;
      AdminFeedback.success(
        context,
        settled == null || settled.isBookable
            ? 'Slot is now bookable.'
            : 'Slot is now blocked.',
      );
    } catch (error) {
      if (!context.mounted) return;
      AdminFeedback.error(context, _messageOf(error, 'update this slot'));
    }
  }

  Future<void> _confirmDelete(BuildContext context, CourtSlot slot) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete this slot?',
      message:
          'Deleting ${slot.windowLabel} removes it from the schedule. Existing '
          'bookings in this window may be affected. This cannot be undone.',
      confirmLabel: 'Delete slot',
      destructive: true,
      icon: Icons.schedule_rounded,
    );

    if (!confirmed || !context.mounted) return;

    try {
      await controller.delete(slot.id);
      if (!context.mounted) return;
      AdminFeedback.success(context, 'Slot deleted.');
    } catch (error) {
      if (!context.mounted) return;
      // The controller has already put the row back.
      AdminFeedback.error(context, _messageOf(error, 'delete this slot'));
    }
  }

  static String _messageOf(Object error, String action) {
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.isEmpty ? 'Could not $action.' : text;
  }
}

// -----------------------------------------------------------------------------
// Chrome
// -----------------------------------------------------------------------------

class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({required this.controller});

  final CourtSlotsController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < AdminTokens.mobileMax;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: SlotsView.values.map((view) {
            final selected = controller.view == view;

            return GestureDetector(
              onTap: () => controller.setView(view),
              child: AnimatedContainer(
                duration: AdminTokens.fast,
                padding: const EdgeInsets.symmetric(
                  horizontal: AdminTokens.space4,
                  vertical: AdminTokens.space2 + 2,
                ),
                decoration: BoxDecoration(
                  color: selected ? tokens.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
                  boxShadow: selected ? tokens.softShadow : null,
                ),
                child: Text(
                  narrow ? view.shortLabel : view.label,
                  style: TextStyle(
                    color: selected ? tokens.accent : tokens.textSecondary,
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// The five figures above the schedule.
class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.controller});

  final CourtSlotsController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    final loading = controller.isFirstLoad;

    final cards = <Widget>[
      StatCard(
        label: 'Total slots',
        value: loading ? null : summary.total,
        icon: Icons.schedule_rounded,
        gradient: const [Color(0xFF1A237E), Color(0xFF3F51B5)],
      ),
      StatCard(
        label: 'Bookable',
        value: loading ? null : summary.active,
        icon: Icons.check_circle_outline_rounded,
        gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
      ),
      StatCard(
        label: 'Blocked',
        value: loading ? null : summary.blocked,
        icon: Icons.block_rounded,
        gradient: const [Color(0xFFEF4444), Color(0xFFFCA5A5)],
      ),
      StatCard(
        label: 'Regular slots',
        value: loading ? null : summary.regular,
        icon: Icons.category_outlined,
        gradient: const [Color(0xFF0EA5E9), Color(0xFF67E8F9)],
      ),
      StatCard(
        label: 'Custom price',
        value: loading ? null : summary.customPrice,
        icon: Icons.price_change_outlined,
        gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000 ? 5 : 2;
        const gap = AdminTokens.space4;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map((card) => SizedBox(width: cardWidth, child: card))
              .toList(),
        );
      },
    );
  }
}
