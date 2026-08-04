import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/sport.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import 'complex_picker_field.dart';

/// Moves a sport to another sports complex
/// (`POST /sports/{sportId}/assign-ground`).
///
/// Deliberately its own dialog rather than a trip through the edit form: this
/// is a one-field decision, and reassigning a sport is a different intent from
/// editing its description.
class AssignComplexDialog extends StatefulWidget {
  const AssignComplexDialog({
    super.key,
    required this.sport,
    required this.onSubmit,
    required this.complexes,
    required this.complexesState,
    required this.onReloadComplexes,
  });

  final Sport sport;

  /// Throws on failure so this dialog can stay open and explain itself.
  final Future<void> Function(int sportComplexId) onSubmit;

  final List<SportsComplex> complexes;
  final ViewState complexesState;
  final VoidCallback onReloadComplexes;

  /// Resolves to true when the assignment succeeded.
  static Future<bool> show(
    BuildContext context, {
    required Sport sport,
    required Future<void> Function(int sportComplexId) onSubmit,
    required List<SportsComplex> complexes,
    required ViewState complexesState,
    required VoidCallback onReloadComplexes,
  }) async {
    AdminLog.ui('Assign-complex dialog opened for sport ${sport.id}');

    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => AssignComplexDialog(
        sport: sport,
        onSubmit: onSubmit,
        complexes: complexes,
        complexesState: complexesState,
        onReloadComplexes: onReloadComplexes,
      ),
    );

    AdminLog.ui('Assign-complex dialog closed (done: ${done ?? false})');
    return done ?? false;
  }

  @override
  State<AssignComplexDialog> createState() => _AssignComplexDialogState();
}

class _AssignComplexDialogState extends State<AssignComplexDialog> {
  final _formKey = GlobalKey<FormState>();

  SportsComplex? _complex;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _complex = _currentComplex();
  }

  SportsComplex? _currentComplex() {
    final id = widget.sport.sportComplexId;
    if (id == null) return null;
    for (final complex in widget.complexes) {
      if (complex.id == id) return complex;
    }
    return null;
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final complex = _complex;
    if (complex == null) return;

    // Nothing to do — say so rather than spending a round trip on a no-op.
    if (complex.id == widget.sport.sportComplexId) {
      setState(
        () => _error = '${widget.sport.displayName} is already at this complex.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSubmit(complex.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      AdminLog.failure(
        'Assign-complex crashed',
        error: error,
        stackTrace: stackTrace,
      );
      setState(() {
        _saving = false;
        _error = 'Could not reassign this sport. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final sport = widget.sport;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                      Icons.swap_horiz_rounded,
                      color: tokens.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AdminTokens.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Assign sports complex',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          sport.displayName,
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
              if (_error != null) ...[
                _ErrorBlock(message: _error!),
                const SizedBox(height: AdminTokens.space4),
              ],
              _CurrentComplex(sport: sport),
              const SizedBox(height: AdminTokens.space4),
              Form(
                key: _formKey,
                child: ComplexPickerField(
                  complexes: widget.complexes,
                  state: widget.complexesState,
                  onReload: widget.onReloadComplexes,
                  initialComplex: _complex,
                  enabled: !_saving,
                  onChanged: (complex) {
                    setState(() {
                      _complex = complex;
                      // Clears the "already at this complex" note the moment a
                      // different venue is picked.
                      _error = null;
                    });
                  },
                  validator: (complex) =>
                      complex == null ? 'Pick a sports complex' : null,
                ),
              ),
              const SizedBox(height: AdminTokens.space4),
              _Note(
                icon: Icons.info_outline_rounded,
                text:
                    'Moving a sport changes which complex its programs and '
                    'courts belong to.',
              ),
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
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Assign complex'),
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

/// Where the sport lives now, so the admin can see what they are changing from.
class _CurrentComplex extends StatelessWidget {
  const _CurrentComplex({required this.sport});

  final Sport sport;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final name = (sport.sportComplexName ?? '').trim();

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Icon(Icons.stadium_outlined, size: 17, color: tokens.textMuted),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CURRENTLY AT',
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name.isEmpty ? 'Not assigned to a complex' : name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: name.isEmpty
                        ? tokens.textMuted
                        : tokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: tokens.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: tokens.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: tokens.danger),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: tokens.danger,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: tokens.textMuted),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
