import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/coaching_enquiry.dart';
import '../../domain/entities/sport.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/server_field_errors.dart';
import 'admin_form_fields.dart';

/// Log a coaching enquiry taken at the desk (`POST /coaching-enquiries`).
///
/// Resolves to the created enquiry, or null when the desk cancelled.
class CoachingEnquiryFormDialog extends StatefulWidget {
  const CoachingEnquiryFormDialog({
    super.key,
    required this.onSubmit,
    required this.sports,
    required this.sportsState,
    required this.complexes,
    required this.complexesState,
    required this.onReloadOptions,
  });

  final Future<CoachingEnquiry> Function(CoachingEnquiryDraft draft) onSubmit;

  final List<Sport> sports;
  final ViewState sportsState;

  final List<SportsComplex> complexes;
  final ViewState complexesState;

  final VoidCallback onReloadOptions;

  static Future<CoachingEnquiry?> show(
    BuildContext context, {
    required Future<CoachingEnquiry> Function(CoachingEnquiryDraft draft)
    onSubmit,
    required List<Sport> sports,
    required ViewState sportsState,
    required List<SportsComplex> complexes,
    required ViewState complexesState,
    required VoidCallback onReloadOptions,
  }) async {
    AdminLog.ui('Log coaching-enquiry dialog opened');

    final created = await showDialog<CoachingEnquiry>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => CoachingEnquiryFormDialog(
        onSubmit: onSubmit,
        sports: sports,
        sportsState: sportsState,
        complexes: complexes,
        complexesState: complexesState,
        onReloadOptions: onReloadOptions,
      ),
    );

    AdminLog.ui(
      'Log coaching-enquiry dialog closed (created: ${created != null})',
    );
    return created;
  }

  @override
  State<CoachingEnquiryFormDialog> createState() =>
      _CoachingEnquiryFormDialogState();
}

class _CoachingEnquiryFormDialogState extends State<CoachingEnquiryFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _message;

  Sport? _sport;
  SportsComplex? _complex;

  bool _saving = false;
  String? _error;
  ServerFieldErrors _fieldErrors = ServerFieldErrors.none;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController();
    _email = TextEditingController();
    _message = TextEditingController();
    AdminLog.life('CoachingEnquiryFormDialog mounted');
  }

  @override
  void dispose() {
    for (final controller in [_name, _phone, _email, _message]) {
      controller.dispose();
    }
    AdminLog.life('CoachingEnquiryFormDialog disposed');
    super.dispose();
  }

  /// The sports on offer at the chosen complex, falling back to the full list
  /// when the catalogue does not cover it — a stale `/sports` read must never
  /// empty the dropdown.
  List<Sport> get _sportOptions {
    final complexId = _complex?.id;
    if (complexId == null) return widget.sports;

    final scoped = widget.sports
        .where((sport) => sport.sportComplexId == complexId)
        .toList(growable: false);
    return scoped.isEmpty ? widget.sports : scoped;
  }

  Future<void> _submit() async {
    if (_saving) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      AdminLog.ui('Enquiry form failed local validation');
      return;
    }

    final draft = CoachingEnquiryDraft(
      name: _name.text,
      phone: _phone.text,
      email: _email.text,
      sportId: _sport?.id,
      sportComplexId: _complex?.id,
      message: _message.text,
    );

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = ServerFieldErrors.none;
    });

    try {
      final created = await widget.onSubmit(draft);
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } on ApiException catch (error) {
      if (!mounted) return;
      final parsed = ServerFieldErrors.from(error);
      setState(() {
        _saving = false;
        _error = parsed.summary ?? error.message;
        _fieldErrors = parsed;
      });
      _formKey.currentState?.validate();
      AdminLog.failure('Enquiry create rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not log this enquiry. Please try again.';
      });
      AdminLog.failure(
        'Enquiry create crashed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < AdminTokens.mobileMax;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? AdminTokens.space4 : AdminTokens.space8,
        vertical: AdminTokens.space6,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminFormHeader(
              title: 'Log a coaching enquiry',
              subtitle: 'Taken over the phone or at the desk',
              icon: Icons.support_agent_rounded,
              onClose: _saving ? null : () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AdminTokens.space5),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        AdminFormErrorBanner(message: _error!),
                        const SizedBox(height: AdminTokens.space4),
                      ],
                      const AdminFormSection(
                        icon: Icons.person_outline_rounded,
                        label: 'Who is asking',
                        color: Color(0xFF3949AB),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminTextField(
                        controller: _name,
                        label: 'Name',
                        icon: Icons.person_outline_rounded,
                        hint: 'e.g. Rahul Deshpande',
                        required: true,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          final server = _fieldErrors.forKeys(const [
                            'name',
                            'customerName',
                          ]);
                          if (server != null) return server;
                          if ((value ?? '').trim().length < 2) {
                            return 'Enter the full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminFieldPair(
                        narrow: narrow,
                        first: AdminTextField(
                          controller: _phone,
                          label: 'Phone',
                          icon: Icons.phone_outlined,
                          hint: '10-digit mobile number',
                          required: true,
                          enabled: !_saving,
                          keyboardType: TextInputType.phone,
                          // The endpoint takes exactly ten digits, so nothing
                          // else can be typed in the first place.
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (value) {
                            final server = _fieldErrors.forKeys(const [
                              'phone',
                              'phoneNumber',
                              'phone_number',
                            ]);
                            if (server != null) return server;
                            final digits = (value ?? '').trim();
                            if (digits.isEmpty) return 'Phone is required';
                            if (digits.length != 10) {
                              return 'Must be exactly 10 digits';
                            }
                            return null;
                          },
                        ),
                        second: AdminTextField(
                          controller: _email,
                          label: 'Email',
                          icon: Icons.mail_outline_rounded,
                          hint: 'name@example.com',
                          required: true,
                          enabled: !_saving,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final server = _fieldErrors.forKeys(const [
                              'email',
                            ]);
                            if (server != null) return server;
                            final text = (value ?? '').trim();
                            if (text.isEmpty) return 'Email is required';
                            final valid = RegExp(
                              r'^[\w.+-]+@[\w-]+\.[\w.-]+$',
                            ).hasMatch(text);
                            return valid ? null : 'Enter a valid email';
                          },
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space5),
                      const AdminFormSection(
                        icon: Icons.sports_tennis_outlined,
                        label: 'What they asked about',
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminCatalogueDropdown<SportsComplex>(
                        label: 'Sport complex',
                        icon: Icons.stadium_outlined,
                        options: widget.complexes,
                        value: _complex,
                        labelOf: (complex) => complex.label,
                        idOf: (complex) => complex.id,
                        state: widget.complexesState,
                        onReload: widget.onReloadOptions,
                        enabled: !_saving,
                        required: true,
                        error: _fieldErrors.forKeys(const [
                          'sportComplexId',
                          'sport_complex_id',
                        ]),
                        onChanged: (complex) => setState(() {
                          _complex = complex;
                          // The sport list is scoped by complex, so a stale
                          // pick would point at another venue's sport.
                          if (_sport?.sportComplexId != complex?.id) {
                            _sport = null;
                          }
                        }),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminCatalogueDropdown<Sport>(
                        label: 'Sport',
                        icon: Icons.sports_tennis_outlined,
                        options: _sportOptions,
                        value: _sport,
                        labelOf: (sport) => sport.name ?? 'Sport ${sport.id}',
                        idOf: (sport) => sport.id,
                        state: widget.sportsState,
                        onReload: widget.onReloadOptions,
                        enabled: !_saving,
                        required: true,
                        error: _fieldErrors.forKeys(const [
                          'sportId',
                          'sport_id',
                        ]),
                        onChanged: (sport) => setState(() => _sport = sport),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminTextField(
                        controller: _message,
                        label: 'Message',
                        icon: Icons.chat_bubble_outline_rounded,
                        hint: 'What they want to know',
                        required: true,
                        enabled: !_saving,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (value) {
                          final server = _fieldErrors.forKeys(const [
                            'message',
                          ]);
                          if (server != null) return server;
                          if ((value ?? '').trim().isEmpty) {
                            return 'Enter what the enquiry is about';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      const AdminFormNote(
                        icon: Icons.info_outline_rounded,
                        text:
                            'The enquiry is logged as New. Assign a coach and '
                            'move it along from the detail panel.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AdminFormFooter(
              saving: _saving,
              submitLabel: 'Log enquiry',
              onCancel: _saving ? null : () => Navigator.of(context).pop(),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
