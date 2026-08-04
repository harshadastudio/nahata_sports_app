import 'package:flutter/material.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/booking.dart';
import '../state/bookings_controller.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'court_filter_sheet.dart';

/// The seven booking filters, in a sheet behind the header's Filter button.
///
/// `GET /bookings` documents no filter parameters, so each is sent hopefully
/// *and* re-applied over the rows — which is why using any of them loads the
/// whole catalogue first. The header says so once rather than repeating it on
/// every group.
class BookingFilterSheet extends StatefulWidget {
  const BookingFilterSheet({super.key, required this.controller});

  static Future<void> show(
    BuildContext context,
    BookingsController controller,
  ) {
    AdminLog.ui('Booking filter sheet opened');
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminTheme.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AdminTokens.radiusXl),
        ),
      ),
      builder: (_) => BookingFilterSheet(controller: controller),
    ).whenComplete(() => AdminLog.ui('Booking filter sheet closed'));
  }

  final BookingsController controller;

  @override
  State<BookingFilterSheet> createState() => _BookingFilterSheetState();
}

class _BookingFilterSheetState extends State<BookingFilterSheet> {
  final _sportQuery = TextEditingController();
  final _courtQuery = TextEditingController();
  final _complexQuery = TextEditingController();

  @override
  void dispose() {
    _sportQuery.dispose();
    _courtQuery.dispose();
    _complexQuery.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.controller.dateFilter ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      helpText: 'Filter by booking date',
    );

    if (picked == null) return;
    widget.controller.setDateFilter(picked);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final controller = widget.controller;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.85,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AdminTokens.space5,
                  AdminTokens.space4,
                  AdminTokens.space5,
                  AdminTokens.space5,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.filter_alt_outlined,
                          size: 18,
                          color: tokens.accent,
                        ),
                        const SizedBox(width: AdminTokens.space3),
                        Expanded(
                          child: Text(
                            'Filter bookings',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (controller.activeFilterCount > 0)
                          TextButton.icon(
                            onPressed: () {
                              controller.clearFilters();
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(
                              Icons.filter_alt_off_outlined,
                              size: 16,
                            ),
                            label: const Text('Clear all'),
                          ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: tokens.textMuted,
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: AdminTokens.space2),
                    Text(
                      'The bookings route documents no filter parameters, so '
                      'these are sent hopefully and re-applied here — which '
                      'means every page is loaded first.',
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 11,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    _DateGroup(
                      date: controller.dateFilter,
                      onPick: _pickDate,
                      onClear: () => controller.setDateFilter(null),
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    _Group<BookingStatus>(
                      label: 'Booking status',
                      options: BookingStatus.values,
                      selected: controller.statusFilter,
                      labelOf: (status) => status.label,
                      onSelect: controller.setStatusFilter,
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    _Group<PaymentStatus>(
                      label: 'Payment status',
                      options: PaymentStatus.values,
                      selected: controller.paymentFilter,
                      labelOf: (payment) => payment.label,
                      onSelect: controller.setPaymentFilter,
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    _Group<BookingSource>(
                      label: 'Booking source',
                      options: BookingSource.values,
                      selected: controller.sourceFilter,
                      labelOf: (source) => source.label,
                      onSelect: controller.setSourceFilter,
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    CourtSearchableGroup(
                      label: 'Sport',
                      query: _sportQuery,
                      onQueryChanged: () => setState(() {}),
                      state: controller.sportsState,
                      onReload: () => controller.loadSports(refresh: true),
                      options: [
                        for (final sport in controller.sports)
                          (id: sport.id, label: sport.displayName),
                      ],
                      selectedId: controller.sportFilter,
                      onSelect: controller.setSportFilter,
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    CourtSearchableGroup(
                      label: 'Court',
                      query: _courtQuery,
                      onQueryChanged: () => setState(() {}),
                      state: controller.courtsState,
                      onReload: () => controller.loadCourts(refresh: true),
                      options: [
                        for (final court in controller.courts)
                          (id: court.id, label: court.displayName),
                      ],
                      selectedId: controller.courtFilter,
                      onSelect: controller.setCourtFilter,
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    CourtSearchableGroup(
                      label: 'Sports complex',
                      query: _complexQuery,
                      onQueryChanged: () => setState(() {}),
                      state: controller.complexesState,
                      onReload: () => controller.loadComplexes(refresh: true),
                      options: [
                        for (final complex in controller.complexes)
                          (id: complex.id, label: complex.name),
                      ],
                      selectedId: controller.complexFilter,
                      onSelect: controller.setComplexFilter,
                    ),
                    const SizedBox(height: AdminTokens.space6),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DateGroup extends StatelessWidget {
  const _DateGroup({
    required this.date,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? date;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const CourtGroupLabel('Booking date'),
        const SizedBox(height: AdminTokens.space3),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.calendar_today_rounded, size: 17),
                label: Text(
                  date == null ? 'Any date' : AdminFormat.date(date),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: date == null
                      ? tokens.textPrimary
                      : tokens.accent,
                  side: BorderSide(
                    color: date == null ? tokens.borderStrong : tokens.accent,
                  ),
                ),
              ),
            ),
            if (date != null) ...[
              const SizedBox(width: AdminTokens.space3),
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Clear date',
                color: tokens.textMuted,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Group<T> extends StatelessWidget {
  const _Group({
    required this.label,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });

  final String label;
  final List<T> options;
  final T? selected;
  final String Function(T value) labelOf;
  final ValueChanged<T?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CourtGroupLabel(label),
        const SizedBox(height: AdminTokens.space3),
        Wrap(
          spacing: AdminTokens.space2,
          runSpacing: AdminTokens.space2,
          children: [
            CourtFilterChip(
              label: 'All',
              selected: selected == null,
              onTap: () => onSelect(null),
            ),
            ...options.map(
              (option) => CourtFilterChip(
                label: labelOf(option),
                selected: option == selected,
                // Tapping the selected chip clears it, so the filter can be
                // undone without hunting for "All".
                onTap: () => onSelect(option == selected ? null : option),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
