import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../admin/core/admin_log.dart';
import '../../../admin/domain/entities/event_pass.dart';
import '../../../admin/domain/repositories/event_pass_repository.dart';
import '../../../admin/presentation/state/view_state.dart';
import '../../../admin/presentation/theme/admin_theme.dart';
import '../../../admin/presentation/utils/admin_format.dart';
import '../../../admin/presentation/widgets/admin_states.dart';
import '../../../admin/presentation/widgets/glass_card.dart';
import '../../domain/entities/gate_scan.dart';
import '../state/security_guard_controller.dart';
import '../widgets/gate_page_header.dart';
import '../widgets/scan_stats_row.dart';
import 'gate_scanner_page.dart';

/// The event gate: pick an event, watch its six counters, scan its passes.
///
/// `/event-passes/{id}/scan-stats` is per-event, so an event has to be chosen
/// before there are any figures to show — that is the shape of the API, not a
/// UI decision.
class EventGatePage extends StatefulWidget {
  const EventGatePage({super.key});

  @override
  State<EventGatePage> createState() => _EventGatePageState();
}

class _EventGatePageState extends State<EventGatePage> {
  final TextEditingController _search = TextEditingController();

  List<AdminEventPass> _events = const [];
  ViewState _eventsState = ViewState.idle;
  String? _eventsError;

  AdminEventPass? _selected;
  ScanStats _stats = ScanStats.empty;
  ViewState _statsState = ViewState.idle;
  String? _statsError;

  @override
  void initState() {
    super.initState();
    AdminLog.life('EventGatePage mounted');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadEvents();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    AdminLog.life('EventGatePage disposed');
    super.dispose();
  }

  /// `GET /event-passes?limit=100`
  Future<void> _loadEvents() async {
    setState(() {
      _eventsState = ViewState.loading;
      _eventsError = null;
    });

    try {
      final result = await context
          .read<EventPassRepository>()
          .fetchEventPasses(page: 1, limit: 100);

      if (!mounted) return;
      setState(() {
        _events = result.items;
        _eventsState = ViewState.ready;
      });

      // Straight into the only event, when there is only one.
      if (_events.length == 1) _selectEvent(_events.first);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _eventsState = ViewState.failed;
        _eventsError = _messageOf(error);
      });
    }
  }

  Future<void> _selectEvent(AdminEventPass event) async {
    setState(() {
      _selected = event;
      _statsState = ViewState.loading;
      _statsError = null;
      _stats = ScanStats.empty;
    });
    await _loadStats();
  }

  /// `GET /event-passes/{eventPassId}/scan-stats`
  Future<void> _loadStats() async {
    final event = _selected;
    if (event == null) return;

    setState(() {
      _statsState = ViewState.loading;
      _statsError = null;
    });

    try {
      final stats =
          await context.read<SecurityGuardController>().gates.eventScanStats(
                event.id,
              );
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _statsState = ViewState.ready;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statsState = ViewState.failed;
        _statsError = _messageOf(error);
      });
    }
  }

  Future<void> _openScanner() async {
    final guard = context.read<SecurityGuardController>();

    await GateScannerPage.push(
      context,
      kind: GateScanKind.event,
      title: _selected == null
          ? 'Event Pass Scanner'
          : 'Scan · ${_selected!.title ?? 'Event'}',
      onRecorded: guard.recordScan,
      onScan: (code, direction) => guard.gates.scanEventPass(
        passCode: code,
        direction: direction,
      ),
    );

    if (!mounted) return;
    // Statuses will have moved on while the scanner was open.
    await _loadStats();
  }

  List<AdminEventPass> get _filtered {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return _events;
    return _events
        .where(
          (event) => [
            event.title,
            event.sportComplexName,
          ].any((field) => (field ?? '').toLowerCase().contains(query)),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final isMobile = MediaQuery.sizeOf(context).width < AdminTokens.mobileMax;

    return ColoredBox(
      color: tokens.canvas,
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadEvents();
          await _loadStats();
        },
        child: ListView(
          padding: EdgeInsets.all(
            isMobile ? AdminTokens.space4 : AdminTokens.space6,
          ),
          children: [
            GatePageHeader(
              title: 'Event Pass Scanner',
              subtitle: _selected == null
                  ? 'Pick an event to see its gate figures'
                  : (_selected!.title ?? 'Event'),
              onScan: _openScanner,
            ),
            const SizedBox(height: AdminTokens.space5),

            if (_selected != null) ...[
              SolidCard(
                child: ScanStatsRow(
                  stats: _stats,
                  loading: _statsState.isLoading,
                  error: _statsError,
                  onRetry: _loadStats,
                ),
              ),
              const SizedBox(height: AdminTokens.space5),
            ],

            SolidCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AdminTokens.space4),
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        fontSize: 13.5,
                        color: tokens.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search events by title or venue',
                        isDense: true,
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: tokens.textMuted,
                        ),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded, size: 16),
                                color: tokens.textMuted,
                              ),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: tokens.border),
                  _EventList(
                    state: _eventsState,
                    error: _eventsError,
                    events: _filtered,
                    selected: _selected,
                    onRetry: _loadEvents,
                    onSelect: _selectEvent,
                    onScan: (event) async {
                      await _selectEvent(event);
                      if (mounted) await _openScanner();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AdminTokens.space6),
          ],
        ),
      ),
    );
  }

  static String _messageOf(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.isEmpty ? 'Something went wrong. Please try again.' : text;
  }
}

class _EventList extends StatelessWidget {
  const _EventList({
    required this.state,
    required this.error,
    required this.events,
    required this.selected,
    required this.onRetry,
    required this.onSelect,
    required this.onScan,
  });

  final ViewState state;
  final String? error;
  final List<AdminEventPass> events;
  final AdminEventPass? selected;
  final VoidCallback onRetry;
  final ValueChanged<AdminEventPass> onSelect;
  final ValueChanged<AdminEventPass> onScan;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading || state.isIdle) {
      return const Padding(
        padding: EdgeInsets.all(AdminTokens.space4),
        child: TableShimmer(rows: 4),
      );
    }

    if (state.isFailed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AdminTokens.space6),
        child: ErrorStateView(
          compact: true,
          title: 'Events unavailable',
          message: error ?? 'The event list could not be loaded.',
          onRetry: onRetry,
        ),
      );
    }

    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AdminTokens.space6),
        child: EmptyStateView(
          icon: Icons.event_busy_rounded,
          title: 'No events',
          message: 'Events appear here once they have been published.',
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AdminTokens.space3),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: AdminTokens.space2),
      itemBuilder: (context, index) {
        final event = events[index];
        return _EventTile(
          event: event,
          selected: selected?.id == event.id,
          onTap: () => onSelect(event),
          onScan: () => onScan(event),
        );
      },
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.selected,
    required this.onTap,
    required this.onScan,
  });

  final AdminEventPass event;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final image = (event.image ?? '').trim();
    final slot = event.slots.isEmpty ? null : event.slots.first;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AdminTokens.space3),
        decoration: BoxDecoration(
          color: selected ? tokens.accentSoft : tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          border: Border.all(
            color: selected ? tokens.accent : tokens.border,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
              child: SizedBox(
                width: 52,
                height: 52,
                child: image.isEmpty
                    ? ColoredBox(
                        color: tokens.surface,
                        child: Icon(
                          Icons.event_rounded,
                          color: tokens.textMuted,
                          size: 22,
                        ),
                      )
                    : Image.network(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ColoredBox(
                          color: tokens.surface,
                          child: Icon(
                            Icons.event_rounded,
                            color: tokens.textMuted,
                            size: 22,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: AdminTokens.space3),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title ?? 'Event',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  Text(
                    [
                      if (slot?.date != null) AdminFormat.date(slot!.date),
                      if ((event.sportComplexName ?? '').trim().isNotEmpty)
                        event.sportComplexName!.trim(),
                      if (slot?.capacity != null) '${slot!.capacity} slots',
                      if ((event.statusRaw ?? '').trim().isNotEmpty)
                        event.statusRaw!.trim(),
                    ].join(' · '),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AdminTokens.space2),
            IconButton(
              onPressed: onScan,
              tooltip: 'Scan for this event',
              color: tokens.accent,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
