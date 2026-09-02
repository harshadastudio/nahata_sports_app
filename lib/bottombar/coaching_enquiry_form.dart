import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/profile_model.dart';
import '../repositories/coaching_repository.dart';
import 'profile.dart' show Batch, Coach;

/// The enrollment enquiry form, raised from a coach's page.
///
/// `POST /coaching-enquiries` with `{batchId, sportId, coachId, name, email,
/// phone, message}`. The route is login-gated — the enquiry is filed against
/// the bearer token's user — so the caller checks for a session first and
/// hands the signed-in profile in.
///
/// The three contact fields are prefilled from the cached profile but stay
/// editable: the enquiry is followed up by phone, and the number on the
/// account is not always the one the enquirer wants to be called on.
class CoachingEnquiryForm extends StatefulWidget {
  const CoachingEnquiryForm({
    super.key,
    required this.batch,
    required this.coach,
    required this.profile,
  });

  final Batch batch;
  final Coach coach;
  final ProfileModel profile;

  /// Opens the form and resolves to the submitted [EnquiryResult], or null if
  /// the user cancelled.
  ///
  /// [profile] is the signed-in user — the route files the enquiry against the
  /// bearer token, so the caller does the login check and this never has to
  /// guess whether a null result meant "cancelled" or "not signed in".
  static Future<EnquiryResult?> show(
    BuildContext context, {
    required Batch batch,
    required Coach coach,
    required ProfileModel profile,
  }) {
    return showDialog<EnquiryResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          CoachingEnquiryForm(batch: batch, coach: coach, profile: profile),
    );
  }

  @override
  State<CoachingEnquiryForm> createState() => _CoachingEnquiryFormState();
}

class _CoachingEnquiryFormState extends State<CoachingEnquiryForm> {
  static const Color _navy = Color(0xFF1A237E);

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name = TextEditingController(
    text: widget.profile.displayName,
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.profile.email ?? '',
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.profile.phoneNumber ?? '',
  );
  final TextEditingController _message = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final result = await CoachingRepository.instance.submitEnquiry(
      batchId: int.tryParse(widget.batch.id),
      sportId: int.tryParse(widget.batch.sportId),
      coachId: int.tryParse(widget.coach.id),
      name: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      message: _message.text.trim(),
    );

    if (!mounted) return;

    // A failure keeps the form open with everything the user typed still in
    // it, so a rejected phone number is one edit away from a retry.
    if (!result.success) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final batch = widget.batch;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        // The form scrolls inside the dialog rather than growing past the
        // screen when the keyboard is up.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 520,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(batch),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _field(
                        label: 'FULL NAME',
                        controller: _name,
                        required: true,
                        hint: 'Your full name',
                        textCapitalization: TextCapitalization.words,
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Please enter your name.'
                            : null,
                      ),
                      _field(
                        label: 'EMAIL ADDRESS',
                        controller: _email,
                        required: true,
                        hint: 'you@example.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty) return 'Please enter your email.';
                          // Deliberately loose: the only thing worth rejecting
                          // here is a value that cannot be an address at all.
                          if (!RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(text)) {
                            return 'Enter a valid email address.';
                          }
                          return null;
                        },
                      ),
                      _field(
                        label: 'PHONE NUMBER',
                        controller: _phone,
                        required: true,
                        hint: '10-digit mobile number',
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (value) {
                          final digits = (value ?? '').replaceAll(
                            RegExp(r'\D'),
                            '',
                          );
                          if (digits.isEmpty) {
                            return 'Please enter your phone number.';
                          }
                          if (digits.length != 10) {
                            return 'The phone number must be 10 digits.';
                          }
                          return null;
                        },
                      ),
                      _field(
                        label: 'MESSAGE',
                        controller: _message,
                        required: false,
                        optionalNote: '(OPTIONAL)',
                        hint: 'Anything you would like the coach to know',
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 8),
                      _programDetails(batch),
                    ],
                  ),
                ),
              ),
            ),
            _actions(),
          ],
        ),
      ),
    );
  }

  Widget _header(Batch batch) {
    return Container(
      width: double.infinity,
      color: _navy,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ENROLLMENT ENQUIRY',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
          if (batch.name.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              batch.name.trim().toUpperCase(),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required bool required,
    String? hint,
    String? optionalNote,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.black54,
                  letterSpacing: 0.5,
                ),
              ),
              if (required)
                const Text(
                  ' *',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.red,
                  ),
                ),
              if (optionalNote != null) const SizedBox(width: 4),
              if (optionalNote != null)
                Text(
                  optionalNote,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.black38,
                    letterSpacing: 0.5,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            enabled: !_submitting,
            maxLines: maxLines,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            validator: validator,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 13, color: Colors.black26),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              filled: true,
              fillColor: const Color(0xFFF6F7F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _navy, width: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The batch the enquiry is about, so the user can see what they are asking
  /// for without leaving the form. Rows the API did not fill are dropped.
  Widget _programDetails(Batch batch) {
    final rows = <(String, String)>[
      ('Batch', batch.name.trim()),
      ('Coach', widget.coach.name.trim()),
      ('Price', batch.price.trim().isEmpty ? '' : '₹${batch.price.trim()}'),
      ('Timing', batch.timingLabel),
      ('Days', batch.days.trim()),
      ('Duration', batch.duration.trim()),
      ('Age Group', batch.ageGroup.trim()),
      ('Available Spots', batch.availableSpots?.toString() ?? ''),
      ('Status', batch.status.trim()),
    ].where((row) => row.$2.isNotEmpty && row.$2 != '-').toList();

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PROGRAM DETAILS',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.black54,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 118,
                    child: Text(
                      row.$1,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _actions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _submitting ? null : () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                disabledBackgroundColor: _navy.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'SUBMIT ENQUIRY',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
