import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/coach.dart';
import '../../domain/entities/coaching_enquiry.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import 'admin_form_fields.dart';
import 'enquiry_status_chip.dart';

/// Move an enquiry to another state (`PATCH /coaching-enquiries/{id}/status`).
///
/// The picker and the confirmation are the same dialog: a two-step flow for a
/// one-field change would only be clicked through. The submit button names the
/// destination, so what is about to happen is on the button itself.
class EnquiryStatusDialog extends StatefulWidget {
  const EnquiryStatusDialog({
    super.key,
    required this.enquiry,
    required this.onSubmit,
  });

  final CoachingEnquiry enquiry;
  final Future<void> Function(CoachingEnquiryStatus status) onSubmit;

  static Future<bool> show(
    BuildContext context, {
    required CoachingEnquiry enquiry,
    required Future<void> Function(CoachingEnquiryStatus status) onSubmit,
  }) async {
    AdminLog.ui('Status dialog opened for enquiry ${enquiry.id}');

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => EnquiryStatusDialog(enquiry: enquiry, onSubmit: onSubmit),
    );

    AdminLog.ui('Status dialog closed (changed: ${changed ?? false})');
    return changed ?? false;
  }

  @override
  State<EnquiryStatusDialog> createState() => _EnquiryStatusDialogState();
}

class _EnquiryStatusDialogState extends State<EnquiryStatusDialog> {
  CoachingEnquiryStatus? _status;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _status = widget.enquiry.status;
  }

  bool get _unchanged => _status == widget.enquiry.status;

  Future<void> _submit() async {
    final status = _status;
    if (_saving || status == null || _unchanged) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSubmit(status);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
      AdminLog.failure('Status change rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not change the status. Please try again.';
      });
      AdminLog.failure(
        'Status change crashed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final target = _status;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(AdminTokens.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.accent.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      Icons.flag_outlined,
                      size: 20,
                      color: tokens.accent,
                    ),
                  ),
                  const SizedBox(width: AdminTokens.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Change status',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          widget.enquiry.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AdminTokens.space5),
              Row(
                children: [
                  Text(
                    'Now',
                    style: TextStyle(color: tokens.textMuted, fontSize: 12),
                  ),
                  const SizedBox(width: AdminTokens.space3),
                  EnquiryStatusChip(statusRaw: widget.enquiry.statusRaw),
                  const SizedBox(width: AdminTokens.space3),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: tokens.textMuted,
                  ),
                  const SizedBox(width: AdminTokens.space3),
                  if (target != null)
                    EnquiryStatusChip(statusRaw: target.slug)
                  else
                    Text(
                      'Pick one',
                      style: TextStyle(color: tokens.textMuted, fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: AdminTokens.space5),
              AdminVocabularyDropdown<CoachingEnquiryStatus>(
                label: 'New status',
                icon: Icons.flag_outlined,
                value: _status,
                required: true,
                enabled: !_saving,
                items: CoachingEnquiryStatus.values,
                labelOf: (status) => status.label,
                onChanged: (status) => setState(() => _status = status),
              ),
              if (target != null && target.isSettled && !_unchanged) ...[
                const SizedBox(height: AdminTokens.space4),
                AdminFormNote(
                  icon: Icons.info_outline_rounded,
                  text: target == CoachingEnquiryStatus.joined
                      ? 'Marking this Joined records the enquiry as converted. '
                            'It stays in the list and can still be reopened.'
                      : 'Closing this enquiry stops the follow-up. It stays in '
                            'the list and can still be reopened.',
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AdminTokens.space4),
                AdminFormErrorBanner(message: _error!),
              ],
              const SizedBox(height: AdminTokens.space6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.textSecondary,
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AdminTokens.space3),
                  FilledButton(
                    // Confirmation is the button itself: it is dead until a
                    // *different* status is chosen, and says which one.
                    onPressed: _saving || _unchanged || target == null
                        ? null
                        : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            target == null || _unchanged
                                ? 'Choose a status'
                                : 'Mark ${target.label}',
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Assign or reassign the coach who will follow an enquiry up
/// (`PATCH /coaching-enquiries/{id}/assign-coach`).
class AssignCoachDialog extends StatefulWidget {
  const AssignCoachDialog({
    super.key,
    required this.enquiry,
    required this.coaches,
    required this.coachesState,
    required this.onReload,
    required this.onSubmit,
  });

  final CoachingEnquiry enquiry;
  final List<Coach> coaches;
  final ViewState coachesState;
  final VoidCallback onReload;
  final Future<void> Function(Coach coach) onSubmit;

  static Future<bool> show(
    BuildContext context, {
    required CoachingEnquiry enquiry,
    required List<Coach> coaches,
    required ViewState coachesState,
    required VoidCallback onReload,
    required Future<void> Function(Coach coach) onSubmit,
  }) async {
    AdminLog.ui('Assign-coach dialog opened for enquiry ${enquiry.id}');

    final assigned = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => AssignCoachDialog(
        enquiry: enquiry,
        coaches: coaches,
        coachesState: coachesState,
        onReload: onReload,
        onSubmit: onSubmit,
      ),
    );

    AdminLog.ui('Assign-coach dialog closed (assigned: ${assigned ?? false})');
    return assigned ?? false;
  }

  @override
  State<AssignCoachDialog> createState() => _AssignCoachDialogState();
}

class _AssignCoachDialogState extends State<AssignCoachDialog> {
  final TextEditingController _search = TextEditingController();

  String _query = '';
  Coach? _selected;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = _matchAssigned();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Coach? _matchAssigned() {
    final id = widget.enquiry.assignedCoachId;
    if (id == null) return null;
    for (final coach in widget.coaches) {
      if (coach.id == id) return coach;
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant AssignCoachDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The coach list may land after the dialog opened; preselect once it does.
    if (_selected == null && widget.coaches.isNotEmpty) {
      final matched = _matchAssigned();
      if (matched != null) setState(() => _selected = matched);
    }
  }

  /// Local filtering — the whole coach list is already in memory, so a debounce
  /// and a round trip would only add latency.
  List<Coach> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.coaches;

    return widget.coaches
        .where((coach) {
          final haystack = [
            coach.name ?? '',
            coach.sportName ?? '',
            coach.sportComplexName ?? '',
            coach.email ?? '',
            ...coach.sportNames,
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _submit() async {
    final coach = _selected;
    if (_saving || coach == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSubmit(coach);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
      AdminLog.failure('Assign coach rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not assign this coach. Please try again.';
      });
      AdminLog.failure(
        'Assign coach crashed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final size = MediaQuery.sizeOf(context);
    final results = _filtered;

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminFormHeader(
              title: widget.enquiry.isAssigned
                  ? 'Reassign coach'
                  : 'Assign a coach',
              subtitle: widget.enquiry.displayName,
              icon: Icons.person_add_alt_1_outlined,
              onClose: _saving ? null : () => Navigator.of(context).pop(false),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AdminTokens.space5,
                AdminTokens.space4,
                AdminTokens.space5,
                AdminTokens.space3,
              ),
              child: TextField(
                controller: _search,
                autofocus: true,
                enabled: !_saving,
                onChanged: (value) => setState(() => _query = value),
                style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search by name, sport or complex',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: tokens.textMuted,
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded, size: 16),
                          color: tokens.textMuted,
                          tooltip: 'Clear',
                        ),
                ),
              ),
            ),
            Flexible(
              child: _CoachList(
                coaches: results,
                total: widget.coaches.length,
                state: widget.coachesState,
                query: _query,
                selectedId: _selected?.id,
                enabled: !_saving,
                onReload: widget.onReload,
                onSelect: (coach) => setState(() => _selected = coach),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AdminTokens.space5,
                  AdminTokens.space3,
                  AdminTokens.space5,
                  0,
                ),
                child: AdminFormErrorBanner(message: _error!),
              ),
            AdminFormFooter(
              saving: _saving,
              submitLabel: _selected == null
                  ? 'Select a coach'
                  : 'Assign ${_selected!.name ?? 'coach'}',
              onCancel: _saving ? null : () => Navigator.of(context).pop(false),
              onSubmit: _selected == null ? () {} : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachList extends StatelessWidget {
  const _CoachList({
    required this.coaches,
    required this.total,
    required this.state,
    required this.query,
    required this.selectedId,
    required this.enabled,
    required this.onReload,
    required this.onSelect,
  });

  final List<Coach> coaches;
  final int total;
  final ViewState state;
  final String query;
  final int? selectedId;
  final bool enabled;
  final VoidCallback onReload;
  final ValueChanged<Coach> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    if (state.isLoading && total == 0) {
      return const Padding(
        padding: EdgeInsets.all(AdminTokens.space8),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (coaches.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AdminTokens.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              total == 0 ? Icons.cloud_off_rounded : Icons.search_off_rounded,
              size: 30,
              color: tokens.textMuted,
            ),
            const SizedBox(height: AdminTokens.space3),
            Text(
              total == 0
                  ? 'No coaches are available to assign'
                  : 'No coach matches "$query"',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.textSecondary, fontSize: 13),
            ),
            if (total == 0) ...[
              const SizedBox(height: AdminTokens.space4),
              OutlinedButton.icon(
                onPressed: onReload,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Reload'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: AdminTokens.space4),
      itemCount: coaches.length,
      itemBuilder: (context, index) {
        final coach = coaches[index];
        final selected = coach.id == selectedId;

        final subtitle = [
          if ((coach.sportName ?? '').trim().isNotEmpty)
            coach.sportName!.trim(),
          if ((coach.sportComplexName ?? '').trim().isNotEmpty)
            coach.sportComplexName!.trim(),
        ].join(' · ');

        return ListTile(
          onTap: enabled ? () => onSelect(coach) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          ),
          selected: selected,
          selectedTileColor: tokens.accentSoft,
          leading: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: tokens.avatarGradient(coach.id.toString()),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Text(
              _initialsOf(coach.name),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          title: Text(
            coach.name ?? 'Coach ${coach.id}',
            style: TextStyle(
              color: selected ? tokens.accent : tokens.textPrimary,
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          subtitle: subtitle.isEmpty
              ? null
              : Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
          trailing: selected
              ? Icon(Icons.check_circle_rounded, size: 18, color: tokens.accent)
              : null,
        );
      },
    );
  }

  static String _initialsOf(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// Edit the desk's notes, and optionally the status with them
/// (`PUT /coaching-enquiries/{id}`).
class EnquiryRemarksDialog extends StatefulWidget {
  const EnquiryRemarksDialog({
    super.key,
    required this.enquiry,
    required this.onSubmit,
  });

  final CoachingEnquiry enquiry;
  final Future<void> Function(CoachingEnquiryUpdate update) onSubmit;

  static Future<bool> show(
    BuildContext context, {
    required CoachingEnquiry enquiry,
    required Future<void> Function(CoachingEnquiryUpdate update) onSubmit,
  }) async {
    AdminLog.ui('Remarks dialog opened for enquiry ${enquiry.id}');

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) =>
          EnquiryRemarksDialog(enquiry: enquiry, onSubmit: onSubmit),
    );

    AdminLog.ui('Remarks dialog closed (saved: ${saved ?? false})');
    return saved ?? false;
  }

  @override
  State<EnquiryRemarksDialog> createState() => _EnquiryRemarksDialogState();
}

class _EnquiryRemarksDialogState extends State<EnquiryRemarksDialog> {
  late final TextEditingController _remarks;
  CoachingEnquiryStatus? _status;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _remarks = TextEditingController(text: widget.enquiry.remarks ?? '');
    _status = widget.enquiry.status;
  }

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  bool get _remarksChanged =>
      _remarks.text.trim() != (widget.enquiry.remarks ?? '').trim();

  bool get _statusChanged => _status != widget.enquiry.status;

  Future<void> _submit() async {
    if (_saving) return;

    if (!_remarksChanged && !_statusChanged) {
      setState(() => _error = 'Nothing has been changed yet.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSubmit(
        CoachingEnquiryUpdate(
          // Only what was touched, so this never overwrites the other field
          // with a stale value.
          status: _statusChanged ? _status : null,
          remarks: _remarksChanged ? _remarks.text : null,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
      AdminLog.failure('Remarks update rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this update. Please try again.';
      });
      AdminLog.failure(
        'Remarks update crashed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminFormHeader(
              title: 'Update enquiry',
              subtitle: widget.enquiry.displayName,
              icon: Icons.edit_note_rounded,
              onClose: _saving ? null : () => Navigator.of(context).pop(false),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AdminTokens.space5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      AdminFormErrorBanner(message: _error!),
                      const SizedBox(height: AdminTokens.space4),
                    ],
                    AdminVocabularyDropdown<CoachingEnquiryStatus>(
                      label: 'Status',
                      icon: Icons.flag_outlined,
                      value: _status,
                      enabled: !_saving,
                      items: CoachingEnquiryStatus.values,
                      labelOf: (status) => status.label,
                      onChanged: (status) => setState(() {
                        _status = status;
                        _error = null;
                      }),
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    AdminTextField(
                      controller: _remarks,
                      label: 'Remarks',
                      icon: Icons.sticky_note_2_outlined,
                      hint: 'What was discussed, what happens next',
                      enabled: !_saving,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() => _error = null),
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    const AdminFormNote(
                      icon: Icons.info_outline_rounded,
                      text:
                          'Remarks are internal — they are not shown to the '
                          'person who made the enquiry.',
                    ),
                  ],
                ),
              ),
            ),
            AdminFormFooter(
              saving: _saving,
              submitLabel: 'Save update',
              onCancel: _saving ? null : () => Navigator.of(context).pop(false),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
