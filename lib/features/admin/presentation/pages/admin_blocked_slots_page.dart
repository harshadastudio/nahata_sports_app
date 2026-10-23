import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/court.dart';
import '../../domain/entities/court_slot.dart';
import '../../domain/repositories/court_repository.dart';
import '../../domain/repositories/court_slot_repository.dart';
import '../navigation/admin_module.dart';
import '../state/admin_blocked_slots_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/admin_form_fields.dart';
import '../widgets/admin_states.dart';
import '../widgets/glass_card.dart';

/// Blocked Slots — close a court for a date, or book it as revenue.
///
/// Mirrors the Employee panel's Blocked Slots screen, but with the fuller
/// action set the admin API documents: BLOCK (no revenue) vs BOOK (billed,
/// with an editable amount and notes), the un-bill/re-bill correction on an
/// existing block, and the recurring (`Template`) block toggle.
class AdminBlockedSlotsPage extends StatelessWidget {
  const AdminBlockedSlotsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdminBlockedSlotsController>(
      create: (context) => AdminBlockedSlotsController(
        context.read<CourtRepository>(),
        context.read<CourtSlotRepository>(),
      )..loadCourts(),
      child: const _BlockedSlotsView(),
    );
  }
}

class _BlockedSlotsView extends StatefulWidget {
  const _BlockedSlotsView();

  @override
  State<_BlockedSlotsView> createState() => _BlockedSlotsViewState();
}

class _BlockedSlotsViewState extends State<_BlockedSlotsView> {
  bool get _canWrite => AdminAccess.canEdit(AdminModules.courts);

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AdminBlockedSlotsController>();
    final tokens = AdminTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < AdminTokens.mobileMax;

    return ColoredBox(
      color: tokens.canvas,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(
          isMobile ? AdminTokens.space4 : AdminTokens.space6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(tokens, controller),
            const SizedBox(height: AdminTokens.space4),
            SolidCard(child: _selector(context, controller, tokens)),
            const SizedBox(height: AdminTokens.space4),
            ..._body(context, controller, tokens, isMobile),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _header(AdminTokens tokens, AdminBlockedSlotsController controller) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Blocked Slots',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: tokens.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                controller.fetched
                    ? '${controller.blockedCount} of '
                        '${controller.slots.length} blocked'
                    : 'Close a court for a date — maintenance or an event',
                style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        if (controller.fetched)
          OutlinedButton.icon(
            onPressed: controller.state.isLoading ? null : controller.fetchSlots,
            icon: controller.state.isLoading
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Selector
  // ---------------------------------------------------------------------------

  Widget _selector(
    BuildContext context,
    AdminBlockedSlotsController controller,
    AdminTokens tokens,
  ) {
    final courts = controller.courts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminCatalogueDropdown<Court>(
          label: 'Court',
          icon: Icons.grid_view_outlined,
          options: courts,
          value: controller.court,
          labelOf: (c) => c.displayName,
          idOf: (c) => c.id,
          state: controller.courtsState,
          onReload: () => controller.loadCourts(refresh: true),
          enabled: true,
          onChanged: controller.selectCourt,
        ),
        const SizedBox(height: AdminTokens.space4),
        AdminFieldLabel('Date'),
        const SizedBox(height: AdminTokens.space2),
        OutlinedButton.icon(
          onPressed: () => _pickDate(context, controller),
          icon: const Icon(Icons.calendar_today_rounded, size: 17),
          label: Text(
            '${controller.date.day}/${controller.date.month}/'
            '${controller.date.year}',
          ),
        ),
        const SizedBox(height: AdminTokens.space4),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: controller.canFetch && !controller.state.isLoading
                ? controller.fetchSlots
                : null,
            icon: controller.state.isLoading
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
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    AdminBlockedSlotsController controller,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.date,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 1),
      helpText: 'Select a date',
    );
    if (picked == null) return;
    controller.selectDate(picked);
  }

  // ---------------------------------------------------------------------------
  // Body
  // ---------------------------------------------------------------------------

  List<Widget> _body(
    BuildContext context,
    AdminBlockedSlotsController controller,
    AdminTokens tokens,
    bool isMobile,
  ) {
    if (controller.state.isFailed) {
      return [
        SolidCard(
          child: ErrorStateView(
            compact: true,
            message: controller.error ?? 'That did not load.',
            onRetry: controller.fetched
                ? controller.fetchSlots
                : () => controller.loadCourts(refresh: true),
          ),
        ),
      ];
    }

    if (controller.courts.isEmpty && !controller.courtsState.isLoading) {
      return [
        SolidCard(
          child: EmptyStateView(
            icon: Icons.place_outlined,
            title: 'No courts yet',
            message:
                'Add a court on the Courts screen, then come back to manage '
                'its availability.',
          ),
        ),
      ];
    }

    if (!controller.fetched) {
      return [
        SolidCard(
          child: EmptyStateView(
            icon: Icons.event_available_outlined,
            title: 'Pick a court and date',
            message:
                'Then fetch the time slots to open, close or book them for '
                'that day.',
          ),
        ),
      ];
    }

    if (controller.slots.isEmpty) {
      return [
        SolidCard(
          child: EmptyStateView(
            icon: Icons.schedule_outlined,
            title: 'No slots on this court',
            message: 'Add bookable times on the Manage Slots screen first.',
          ),
        ),
      ];
    }

    final visible = controller.visibleSlots;

    return [
      SolidCard(child: _toolbar(context, controller, tokens)),
      const SizedBox(height: AdminTokens.space4),
      if (visible.isEmpty)
        SolidCard(
          child: EmptyStateView(
            icon: Icons.filter_alt_off_rounded,
            title: 'Nothing to show',
            message: 'No ${controller.filter.label.toLowerCase()} slots for '
                'this court and date.',
          ),
        )
      else
        _tileGrid(context, controller, tokens, visible, isMobile),
      const SizedBox(height: AdminTokens.space4),
      SolidCard(child: _legend(tokens)),
    ];
  }

  Widget _toolbar(
    BuildContext context,
    AdminBlockedSlotsController controller,
    AdminTokens tokens,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in AdminSlotFilter.values) ...[
                if (filter != AdminSlotFilter.values.first)
                  const SizedBox(width: AdminTokens.space2),
                _filterChip(controller, tokens, filter),
              ],
            ],
          ),
        ),
        if (_canWrite) ...[
          const SizedBox(height: AdminTokens.space3),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: controller.busy
                      ? null
                      : () => _bulk(context, controller, block: true),
                  icon: const Icon(Icons.lock_outline_rounded, size: 15),
                  label: const Text(
                    'Block all',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.danger,
                    side: BorderSide(color: tokens.danger.withValues(alpha: 0.4)),
                  ),
                ),
              ),
              const SizedBox(width: AdminTokens.space2),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: controller.busy
                      ? null
                      : () =>
                          _bulk(context, controller, block: true, billed: true),
                  icon: const Icon(Icons.payments_outlined, size: 15),
                  label: const Text(
                    'Book all',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.warning,
                    side: BorderSide(
                      color: tokens.warning.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AdminTokens.space2),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: controller.busy
                      ? null
                      : () => _bulk(context, controller, block: false),
                  icon: const Icon(Icons.lock_open_rounded, size: 15),
                  label: const Text(
                    'Unblock all',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.success,
                    side: BorderSide(
                      color: tokens.success.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _filterChip(
    AdminBlockedSlotsController controller,
    AdminTokens tokens,
    AdminSlotFilter filter,
  ) {
    final active = filter == controller.filter;

    return Material(
      color: active ? tokens.accent : tokens.surface,
      borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
      child: InkWell(
        onTap: () => controller.setFilter(filter),
        borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(
            horizontal: AdminTokens.space4,
            vertical: AdminTokens.space2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
            border: Border.all(color: active ? tokens.accent : tokens.border),
          ),
          alignment: Alignment.center,
          child: Text(
            filter.label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : tokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _tileGrid(
    BuildContext context,
    AdminBlockedSlotsController controller,
    AdminTokens tokens,
    List<AvailableSlot> slots,
    bool isMobile,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = isMobile ? 2 : (constraints.maxWidth ~/ 190).clamp(2, 6);
        const gap = AdminTokens.space3;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final slot in slots)
              SizedBox(
                width: width,
                height: 110,
                child: _slotTile(context, controller, tokens, slot),
              ),
          ],
        );
      },
    );
  }

  Widget _slotTile(
    BuildContext context,
    AdminBlockedSlotsController controller,
    AdminTokens tokens,
    AvailableSlot slot,
  ) {
    final byCustomer = slot.isUserBooked;
    final byPartner = slot.isPartnerBlock;
    final blocked = slot.isBlocked ?? false;
    final busy = controller.busySlotId == slot.slotId;

    final Color background;
    final Color borderColor;
    final Color tone;
    final IconData icon;

    if (byCustomer) {
      tone = tokens.info;
      background = tone.withValues(alpha: 0.08);
      borderColor = tone.withValues(alpha: 0.3);
      icon = Icons.person_rounded;
    } else if (byPartner) {
      tone = tokens.warning;
      background = tone.withValues(alpha: 0.09);
      borderColor = tone.withValues(alpha: 0.35);
      icon = Icons.public_rounded;
    } else if (blocked) {
      tone = tokens.danger;
      background = tone.withValues(alpha: 0.07);
      borderColor = tone.withValues(alpha: 0.3);
      icon = Icons.lock_rounded;
    } else {
      tone = tokens.success;
      background = tokens.surface;
      borderColor = tokens.border;
      icon = Icons.lock_open_rounded;
    }

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
      child: InkWell(
        onTap: byCustomer || busy || !_canWrite
            ? null
            : () => _toggle(context, controller, slot),
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AdminTokens.space3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      slot.windowLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (busy)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: tokens.textMuted,
                      ),
                    )
                  else
                    Icon(icon, size: 15, color: tone),
                ],
              ),
              const SizedBox(height: AdminTokens.space2),
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
                Row(
                  children: [
                    Icon(Icons.repeat_rounded, size: 10, color: tokens.warning),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        'Every date',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: tokens.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (slot.blockBilled) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.currency_rupee_rounded,
                      size: 10,
                      color: tokens.success,
                    ),
                    Expanded(
                      child: Text(
                        '${slot.blockAmount.round()} revenue',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: tokens.success,
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
                    : (_canWrite ? 'Tap for options' : 'View only'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, height: 1.3, color: tokens.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legend(AdminTokens tokens) {
    return Wrap(
      spacing: AdminTokens.space3,
      runSpacing: AdminTokens.space2,
      children: [
        _legendDot(tokens.success, 'Available'),
        _legendDot(tokens.danger, 'Blocked by you'),
        _legendDot(tokens.warning, 'Partner hold'),
        _legendDot(tokens.info, 'Customer booking'),
        _legendDot(tokens.success, '₹ = booked as revenue'),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _toggle(
    BuildContext context,
    AdminBlockedSlotsController controller,
    AvailableSlot slot,
  ) async {
    if (slot.isBlocked ?? false) {
      await _tapBlocked(context, controller, slot);
    } else {
      await _tapAvailable(context, controller, slot);
    }
  }

  Future<void> _tapAvailable(
    BuildContext context,
    AdminBlockedSlotsController controller,
    AvailableSlot slot,
  ) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(slot.windowLabel),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('block'),
            child: const ListTile(
              leading: Icon(Icons.lock_outline_rounded, color: Colors.red),
              title: Text('Block'),
              subtitle: Text('No revenue — maintenance or a closure'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('book'),
            child: const ListTile(
              leading: Icon(Icons.payments_outlined, color: Colors.green),
              title: Text('Book'),
              subtitle: Text('Records this as a paid booking'),
            ),
          ),
        ],
      ),
    );

    if (choice == null || !context.mounted) return;

    if (choice == 'block') {
      final notes = await _promptNotes(context, title: 'Block this slot?');
      if (notes == null || !context.mounted) return;
      final error = await controller.block(
        slot,
        billed: false,
        notes: notes.isEmpty ? null : notes,
      );
      if (!context.mounted) return;
      if (error != null) {
        AdminFeedback.error(context, error);
      } else {
        AdminFeedback.success(context, 'Slot blocked.');
      }
      return;
    }

    final result = await _showBookDialog(context, slot);
    if (result == null || !context.mounted) return;

    final error = await controller.block(
      slot,
      billed: true,
      amount: result.amount,
      notes: result.notes,
    );
    if (!context.mounted) return;
    if (error != null) {
      AdminFeedback.error(context, error);
    } else {
      AdminFeedback.success(
        context,
        'Slot booked — ₹${(result.amount ?? slot.price ?? 0).round()} added '
        'to revenue.',
      );
    }
  }

  Future<void> _tapBlocked(
    BuildContext context,
    AdminBlockedSlotsController controller,
    AvailableSlot slot,
  ) async {
    if (slot.isRecurringBlock) {
      final ok = await ConfirmDialog.show(
        context,
        title: 'This is a recurring block',
        message: 'It applies to every date, not just the one selected. '
            'Unblocking reopens this time on all dates. Continue?',
        confirmLabel: 'Unblock everywhere',
        destructive: true,
      );
      if (!ok || !context.mounted) return;

      final error = await controller.unblock(slot);
      if (!context.mounted) return;
      if (error != null) {
        AdminFeedback.error(context, error);
      } else {
        AdminFeedback.success(context, 'Slot unblocked.');
      }
      return;
    }

    if (slot.isPartnerBlock) {
      final error = await controller.unblock(slot);
      if (!context.mounted) return;
      if (error != null) {
        AdminFeedback.error(context, error);
      } else {
        AdminFeedback.success(context, 'Slot unblocked.');
      }
      return;
    }

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(slot.windowLabel),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('unblock'),
            child: const ListTile(
              leading: Icon(Icons.lock_open_rounded, color: Colors.green),
              title: Text('Unblock'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop('bill'),
            child: ListTile(
              leading: Icon(
                slot.blockBilled ? Icons.money_off_rounded : Icons.payments_outlined,
                color: Colors.orange,
              ),
              title: Text(
                slot.blockBilled ? 'Remove from revenue' : 'Mark as revenue',
              ),
            ),
          ),
        ],
      ),
    );

    if (choice == null || !context.mounted) return;

    if (choice == 'unblock') {
      final error = await controller.unblock(slot);
      if (!context.mounted) return;
      if (error != null) {
        AdminFeedback.error(context, error);
      } else {
        AdminFeedback.success(context, 'Slot unblocked.');
      }
      return;
    }

    final billed = !slot.blockBilled;
    final error = await controller.setBilled(slot, billed);
    if (!context.mounted) return;
    if (error != null) {
      AdminFeedback.error(context, error);
    } else {
      AdminFeedback.success(
        context,
        billed ? 'Marked as revenue.' : 'Revenue removed.',
      );
    }
  }

  Future<String?> _promptNotes(
    BuildContext context, {
    required String title,
  }) async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Notes (optional) — e.g. court maintenance',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Block it'),
          ),
        ],
      ),
    );
    final text = controller.text;
    controller.dispose();
    return saved == true ? text : null;
  }

  Future<_BookInput?> _showBookDialog(
    BuildContext context,
    AvailableSlot slot,
  ) {
    return showDialog<_BookInput>(
      context: context,
      builder: (context) => _BookDialog(slot: slot),
    );
  }

  Future<void> _bulk(
    BuildContext context,
    AdminBlockedSlotsController controller, {
    required bool block,
    bool billed = false,
  }) async {
    final targets = controller.bulkTargets(block: block);

    if (targets.isEmpty) {
      AdminFeedback.info(
        context,
        block ? 'Every slot is already blocked.' : 'Every slot is already open.',
      );
      return;
    }

    final recurring = block ? 0 : controller.recurringAmong(targets);
    final warning = recurring == 0
        ? ''
        : '\n\n$recurring of them are recurring blocks — unblocking those '
            'reopens the time on EVERY date.';
    final revenueNote = block && billed
        ? '\n\nThese are BOOKED AS REVENUE — ₹'
            '${targets.fold<num>(0, (t, s) => t + (s.price ?? 0)).round()} '
            'added to your reports.'
        : '';

    final ok = await ConfirmDialog.show(
      context,
      title: '${block ? (billed ? 'Book' : 'Block') : 'Unblock'} '
          '${targets.length} slot${targets.length == 1 ? '' : 's'}?',
      message: 'Customer bookings are left alone.$revenueNote$warning',
      confirmLabel: block ? (billed ? 'Book them' : 'Block them') : 'Unblock them',
      destructive: block && !billed,
    );
    if (!ok || !context.mounted) return;

    final result = await controller.bulkSet(block: block, billed: billed);
    if (!context.mounted) return;

    if (result.nothingToDo) {
      AdminFeedback.info(context, 'Nothing needed changing.');
      return;
    }

    final message = result.isComplete
        ? '${result.succeeded} slot${result.succeeded == 1 ? '' : 's'} '
            '${block ? (billed ? 'booked' : 'blocked') : 'unblocked'}'
        : '${result.succeeded} of ${result.attempted} updated — check the '
            'grid above';

    if (result.isComplete) {
      AdminFeedback.success(context, message);
    } else {
      AdminFeedback.error(context, message);
    }
  }
}

class _BookInput {
  const _BookInput({this.amount, this.notes});

  final num? amount;
  final String? notes;
}

class _BookDialog extends StatefulWidget {
  const _BookDialog({required this.slot});

  final AvailableSlot slot;

  @override
  State<_BookDialog> createState() => _BookDialogState();
}

class _BookDialogState extends State<_BookDialog> {
  late final TextEditingController _amount;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final price = widget.slot.price;
    _amount = TextEditingController(
      text: price != null && price > 0 ? price.round().toString() : '',
    );
    _notes = TextEditingController();
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Book ${widget.slot.windowLabel}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminTextField(
            controller: _amount,
            label: 'Amount',
            icon: Icons.currency_rupee_rounded,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AdminTokens.space4),
          AdminTextField(
            controller: _notes,
            label: 'Notes',
            icon: Icons.notes_rounded,
            hint: 'Private event, walk-in payment…',
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final amount = num.tryParse(_amount.text.trim());
            Navigator.of(context).pop(
              _BookInput(
                amount: amount,
                notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
              ),
            );
          },
          child: const Text('Book it'),
        ),
      ],
    );
  }
}
