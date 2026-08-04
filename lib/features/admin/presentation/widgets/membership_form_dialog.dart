import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/membership.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import '../utils/server_field_errors.dart';
import 'admin_form_fields.dart';

/// Add / Edit membership.
///
/// [membership] null means create (`POST /memberships`, the full documented
/// body). An edit sends **only the fields that changed**, as the module asks:
/// the `PUT` example carries three keys, and posting the whole record back
/// would overwrite anything another admin touched in between. Status and
/// payment status are not editable here at all — they have their own PATCH
/// routes, and the row menu drives them.
class MembershipFormDialog extends StatefulWidget {
  const MembershipFormDialog({
    super.key,
    required this.onSubmit,
    this.membership,
  });

  final Membership? membership;

  /// Throws on failure so this dialog can stay open and explain itself.
  final Future<void> Function(MembershipDraft draft) onSubmit;

  bool get isEdit => membership != null;

  /// Resolves to true when a save succeeded.
  static Future<bool> show(
    BuildContext context, {
    Membership? membership,
    required Future<void> Function(MembershipDraft draft) onSubmit,
  }) async {
    AdminLog.ui(
      '${membership == null ? 'Add' : 'Edit'} membership dialog opened',
    );

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => MembershipFormDialog(
        membership: membership,
        onSubmit: onSubmit,
      ),
    );

    AdminLog.ui('Membership dialog closed (saved: ${saved ?? false})');
    return saved ?? false;
  }

  @override
  State<MembershipFormDialog> createState() => _MembershipFormDialogState();
}

class _MembershipFormDialogState extends State<MembershipFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _userId;
  late final TextEditingController _planId;
  late final TextEditingController _planName;
  late final TextEditingController _price;
  late final TextEditingController _validity;
  late final TextEditingController _bookings;
  late final TextEditingController _discount;
  late final TextEditingController _accessType;
  late final TextEditingController _features;
  late final TextEditingController _discountApplied;
  late final TextEditingController _totalAmount;

  DateTime? _startDate;
  DateTime? _endDate;
  MembershipStatus _status = MembershipStatus.active;
  MembershipPaymentStatus _paymentStatus = MembershipPaymentStatus.pending;
  bool _autoRenew = false;

  /// True until the admin types their own total, after which the computed
  /// amount stops overwriting it.
  bool _totalIsAuto = true;

  /// Same idea for the end date, which validity otherwise drives.
  bool _endIsAuto = true;

  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    final row = widget.membership;

    _userId = TextEditingController(text: row?.userId ?? '');
    _planId = TextEditingController(text: row?.planId ?? '');
    _planName = TextEditingController(text: row?.planName ?? '');
    _price = TextEditingController(text: _numberText(row?.price));
    _validity = TextEditingController(
      text: row?.validityDays == null ? '' : '${row!.validityDays}',
    );
    _bookings = TextEditingController(
      text: row?.bookingLimit == null ? '' : '${row!.bookingLimit}',
    );
    _discount = TextEditingController(text: _numberText(row?.discountPercent));
    _accessType = TextEditingController(text: row?.accessType ?? '');
    _features = TextEditingController(
      text: MembershipDraft.joinFeatures(row?.features ?? const []),
    );
    _discountApplied = TextEditingController(
      text: _numberText(row?.discountApplied),
    );
    _totalAmount = TextEditingController(text: _numberText(row?.totalAmount));

    _startDate = row?.startDate;
    _endDate = row?.endDate;
    _status = row?.status ?? MembershipStatus.active;
    _paymentStatus = row?.paymentStatus ?? MembershipPaymentStatus.pending;
    _autoRenew = row?.autoRenew ?? false;

    // An existing record's figures are the admin's, not ours to recompute.
    _totalIsAuto = row?.totalAmount == null;
    _endIsAuto = row?.endDate == null;

    AdminLog.life(
      'MembershipFormDialog mounted (${widget.isEdit ? 'edit' : 'create'})',
    );
  }

  static String _numberText(num? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();
  }

  @override
  void dispose() {
    _userId.dispose();
    _planId.dispose();
    _planName.dispose();
    _price.dispose();
    _validity.dispose();
    _bookings.dispose();
    _discount.dispose();
    _accessType.dispose();
    _features.dispose();
    _discountApplied.dispose();
    _totalAmount.dispose();
    AdminLog.life('MembershipFormDialog disposed');
    super.dispose();
  }

  // --- Derived values --------------------------------------------------------

  num? get _priceValue => num.tryParse(_price.text.trim());
  num? get _discountValue => num.tryParse(_discount.text.trim());
  int? get _validityValue => int.tryParse(_validity.text.trim());

  /// Keeps the end date and the total in step with what was typed, unless the
  /// admin has overridden either — then their value stands.
  void _recompute() {
    if (_endIsAuto) {
      final derived = MembershipDraft.endDateFor(_startDate, _validityValue);
      if (derived != null) _endDate = derived;
    }
    if (_totalIsAuto) {
      final derived = MembershipDraft.amountFor(_priceValue, _discountValue);
      _totalAmount.text = derived == null ? '' : _numberText(derived);
    }
    setState(() {});
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final current = start ? _startDate : _endDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? (start ? now : (_startDate ?? now)),
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 6),
      helpText: start ? 'Select the start date' : 'Select the end date',
    );
    if (picked == null || !mounted) return;

    final day = DateTime(picked.year, picked.month, picked.day);
    setState(() {
      if (start) {
        _startDate = day;
      } else {
        _endDate = day;
        // Picked by hand, so validity stops driving it.
        _endIsAuto = false;
      }
    });
    if (start) _recompute();
  }

  /// The first thing wrong that the field validators cannot see themselves.
  String? get _problem {
    if (_startDate == null) return 'Pick the start date.';
    if (_endDate == null) return 'Pick the end date.';
    if (_endDate!.isBefore(_startDate!)) {
      return 'The end date cannot fall before the start date.';
    }
    final discount = _discountValue;
    if (discount != null && (discount < 0 || discount > 100)) {
      return 'The discount must be between 0 and 100 percent.';
    }
    return null;
  }

  MembershipDraft _createDraft() {
    return MembershipDraft(
      userId: _userId.text,
      planId: _planId.text,
      planName: _planName.text,
      price: _priceValue,
      validityDays: _validityValue,
      bookingLimit: int.tryParse(_bookings.text.trim()),
      discountPercent: _discountValue ?? 0,
      accessType: _accessType.text,
      features: MembershipDraft.parseFeatures(_features.text),
      startDate: _startDate,
      endDate: _endDate,
      status: _status,
      paymentStatus: _paymentStatus,
      autoRenew: _autoRenew,
      discountApplied: num.tryParse(_discountApplied.text.trim()) ?? 0,
      totalAmount: num.tryParse(_totalAmount.text.trim()),
    );
  }

  /// Only what actually changed — `toUpdateJson` drops the nulls.
  MembershipDraft _updateDraft() {
    final row = widget.membership!;

    String? textIfChanged(TextEditingController field, String? original) {
      final value = field.text.trim();
      if (value == (original ?? '').trim()) return null;
      return value;
    }

    num? numberIfChanged(TextEditingController field, num? original) {
      final value = num.tryParse(field.text.trim());
      if (value == null || value == original) return null;
      return value;
    }

    int? intIfChanged(TextEditingController field, int? original) {
      final value = int.tryParse(field.text.trim());
      if (value == null || value == original) return null;
      return value;
    }

    final features = MembershipDraft.parseFeatures(_features.text);
    final featuresChanged =
        features.length != row.features.length ||
        !List.generate(
          features.length,
          (i) => features[i] == row.features[i],
        ).every((same) => same);

    bool sameDay(DateTime? a, DateTime? b) =>
        a == null || b == null
        ? a == b
        : (a.year == b.year && a.month == b.month && a.day == b.day);

    return MembershipDraft(
      planId: textIfChanged(_planId, row.planId),
      planName: textIfChanged(_planName, row.planName),
      price: numberIfChanged(_price, row.price),
      validityDays: intIfChanged(_validity, row.validityDays),
      bookingLimit: intIfChanged(_bookings, row.bookingLimit),
      discountPercent: numberIfChanged(_discount, row.discountPercent),
      accessType: textIfChanged(_accessType, row.accessType),
      features: featuresChanged ? features : null,
      startDate: sameDay(_startDate, row.startDate) ? null : _startDate,
      endDate: sameDay(_endDate, row.endDate) ? null : _endDate,
      autoRenew: _autoRenew == (row.autoRenew ?? false) ? null : _autoRenew,
      discountApplied: numberIfChanged(_discountApplied, row.discountApplied),
      totalAmount: numberIfChanged(_totalAmount, row.totalAmount),
    );
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final problem = _problem;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    final draft = widget.isEdit ? _updateDraft() : _createDraft();

    if (widget.isEdit && draft.toUpdateJson().isEmpty) {
      setState(() => _error = 'Nothing has changed yet.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });

    try {
      await widget.onSubmit(draft);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      final parsed = ServerFieldErrors.from(error);
      setState(() {
        _saving = false;
        _error = parsed.summary ?? error.message;
        _fieldErrors = parsed.fields;
      });
      _formKey.currentState?.validate();
      AdminLog.failure('Membership save rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this membership. Please try again.';
      });
      AdminLog.failure(
        'Membership save crashed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  String? _serverError(List<String> keys) {
    for (final key in keys) {
      final message = _fieldErrors[key];
      if (message != null) return message;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < AdminTokens.mobileMax;
    final isEdit = widget.isEdit;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? AdminTokens.space4 : AdminTokens.space8,
        vertical: AdminTokens.space6,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 860,
          maxHeight: size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminFormHeader(
              title: isEdit ? 'Edit membership' : 'Add membership',
              subtitle: isEdit
                  ? '${widget.membership!.displayUser} · '
                        '${widget.membership!.displayPlan}'
                  : 'Sell a plan to a member',
              icon: isEdit
                  ? Icons.edit_outlined
                  : Icons.card_membership_rounded,
              onClose: _saving ? null : () => Navigator.of(context).pop(false),
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
                      if (isEdit) ...[
                        const AdminFormNote(
                          icon: Icons.lock_outline_rounded,
                          text:
                              'Only the fields you change are sent. The member '
                              'cannot be reassigned, and status and payment '
                              'status have their own routes — set them from '
                              'the row menu.',
                        ),
                        const SizedBox(height: AdminTokens.space4),
                      ],

                      // --- 1. Member ----------------------------------------
                      AdminFormSection(
                        icon: Icons.person_outline_rounded,
                        label: 'Member',
                        color: tokens.accent,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      if (isEdit)
                        AdminReadOnlyField(
                          label: 'Member',
                          value: widget.membership!.displayUser,
                          icon: Icons.person_outline_rounded,
                          note: 'A membership cannot be moved to another user.',
                        )
                      else
                        AdminTextField(
                          controller: _userId,
                          label: 'User ID',
                          icon: Icons.badge_outlined,
                          hint: 'The member this plan is for',
                          required: true,
                          enabled: !_saving,
                          validator: (value) {
                            final server = _serverError(const [
                              'userId',
                              'user_id',
                            ]);
                            if (server != null) return server;
                            return (value ?? '').trim().isEmpty
                                ? 'Enter the member’s user ID.'
                                : null;
                          },
                        ),

                      // --- 2. Plan ------------------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      AdminFormSection(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Plan',
                        color: tokens.info,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminFieldPair(
                        narrow: narrow,
                        first: AdminTextField(
                          controller: _planId,
                          label: 'Plan code',
                          icon: Icons.qr_code_2_rounded,
                          hint: 'e.g. GOLD',
                          required: true,
                          enabled: !_saving,
                          textCapitalization: TextCapitalization.characters,
                          validator: (value) {
                            final server = _serverError(const [
                              'planId',
                              'plan_id',
                            ]);
                            if (server != null) return server;
                            return (value ?? '').trim().isEmpty
                                ? 'Give the plan a code.'
                                : null;
                          },
                        ),
                        second: AdminTextField(
                          controller: _planName,
                          label: 'Plan name',
                          icon: Icons.label_outline_rounded,
                          hint: 'e.g. Gold Annual',
                          required: true,
                          enabled: !_saving,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            final server = _serverError(const [
                              'planName',
                              'plan_name',
                            ]);
                            if (server != null) return server;
                            return (value ?? '').trim().isEmpty
                                ? 'Give the plan a name.'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminFieldPair(
                        narrow: narrow,
                        first: AdminTextField(
                          controller: _accessType,
                          label: 'Access type',
                          icon: Icons.vpn_key_outlined,
                          hint: 'e.g. All Courts',
                          enabled: !_saving,
                          textCapitalization: TextCapitalization.words,
                        ),
                        second: AdminTextField(
                          controller: _bookings,
                          label: 'Booking limit',
                          icon: Icons.event_available_outlined,
                          hint: 'Bookings included, e.g. 50',
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminTextField(
                        controller: _features,
                        label: 'Features',
                        icon: Icons.checklist_rounded,
                        hint: 'One per line, e.g.\nPriority booking\n'
                            'Free guest pass',
                        enabled: !_saving,
                        maxLines: 4,
                      ),

                      // --- 3. Money -----------------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      AdminFormSection(
                        icon: Icons.payments_outlined,
                        label: 'Pricing',
                        color: tokens.success,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminFieldPair(
                        narrow: narrow,
                        first: AdminTextField(
                          controller: _price,
                          label: 'Price',
                          icon: Icons.currency_rupee_rounded,
                          hint: 'e.g. 12000',
                          required: true,
                          enabled: !_saving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => _recompute(),
                          validator: (value) {
                            final server = _serverError(const ['price']);
                            if (server != null) return server;
                            final parsed = num.tryParse((value ?? '').trim());
                            if (parsed == null) return 'Enter the price.';
                            if (parsed < 0) {
                              return 'The price cannot be negative.';
                            }
                            return null;
                          },
                        ),
                        second: AdminTextField(
                          controller: _discount,
                          label: 'Discount (%)',
                          icon: Icons.percent_rounded,
                          hint: 'e.g. 10',
                          enabled: !_saving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => _recompute(),
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminFieldPair(
                        narrow: narrow,
                        first: AdminTextField(
                          controller: _discountApplied,
                          label: 'Discount applied (₹)',
                          icon: Icons.local_offer_outlined,
                          hint: 'e.g. 0',
                          enabled: !_saving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                        second: AdminTextField(
                          controller: _totalAmount,
                          label: 'Total amount',
                          icon: Icons.receipt_long_outlined,
                          hint: 'What the member pays',
                          required: true,
                          enabled: !_saving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          // Typing here takes the amount off the computed
                          // value, so a hand-set total is never overwritten.
                          onChanged: (_) => setState(() => _totalIsAuto = false),
                          validator: (value) {
                            final server = _serverError(const [
                              'totalAmount',
                              'total_amount',
                            ]);
                            if (server != null) return server;
                            final parsed = num.tryParse((value ?? '').trim());
                            if (parsed == null) {
                              return 'Enter the amount payable.';
                            }
                            if (parsed < 0) {
                              return 'The amount cannot be negative.';
                            }
                            return null;
                          },
                        ),
                      ),
                      if (_totalIsAuto && _priceValue != null) ...[
                        const SizedBox(height: AdminTokens.space3),
                        AdminFormNote(
                          icon: Icons.functions_rounded,
                          text:
                              'Total is computed from the price and discount '
                              '(${AdminFormat.currency(_priceValue)} less '
                              '${_discountValue ?? 0}%). Type your own to '
                              'override it.',
                        ),
                      ],

                      // --- 4. Term ------------------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      AdminFormSection(
                        icon: Icons.event_rounded,
                        label: 'Validity',
                        color: tokens.warning,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminTextField(
                        controller: _validity,
                        label: 'Validity (days)',
                        icon: Icons.timelapse_rounded,
                        hint: 'e.g. 365',
                        required: true,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => _recompute(),
                        validator: (value) {
                          final server = _serverError(const ['validity']);
                          if (server != null) return server;
                          final parsed = int.tryParse((value ?? '').trim());
                          if (parsed == null) return 'Enter the validity.';
                          if (parsed < 1) {
                            return 'Validity must be at least one day.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminFieldPair(
                        narrow: narrow,
                        first: _DateField(
                          label: 'Start date',
                          value: _startDate,
                          enabled: !_saving,
                          onTap: () => _pickDate(start: true),
                        ),
                        second: _DateField(
                          label: 'End date',
                          value: _endDate,
                          enabled: !_saving,
                          onTap: () => _pickDate(start: false),
                          note: _endIsAuto
                              ? 'Derived from the start date and validity.'
                              : null,
                        ),
                      ),

                      // --- 5. Options ---------------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      AdminFormSection(
                        icon: Icons.tune_rounded,
                        label: 'Options',
                        color: tokens.accent,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      if (!isEdit) ...[
                        AdminFieldPair(
                          narrow: narrow,
                          first: AdminVocabularyDropdown<MembershipStatus>(
                            label: 'Status',
                            icon: Icons.flag_outlined,
                            value: _status,
                            items: MembershipStatus.values,
                            labelOf: (status) => status.label,
                            enabled: !_saving,
                            onChanged: (value) => setState(
                              () => _status = value ?? MembershipStatus.active,
                            ),
                          ),
                          second:
                              AdminVocabularyDropdown<MembershipPaymentStatus>(
                                label: 'Payment status',
                                icon: Icons.payments_outlined,
                                value: _paymentStatus,
                                items: MembershipPaymentStatus.values,
                                labelOf: (payment) => payment.label,
                                enabled: !_saving,
                                onChanged: (value) => setState(
                                  () => _paymentStatus =
                                      value ?? MembershipPaymentStatus.pending,
                                ),
                              ),
                        ),
                        const SizedBox(height: AdminTokens.space4),
                      ] else ...[
                        AdminFieldPair(
                          narrow: narrow,
                          first: AdminReadOnlyField(
                            label: 'Status',
                            value: widget.membership!.statusLabel,
                            icon: Icons.flag_outlined,
                            note: 'Set from the row menu.',
                          ),
                          second: AdminReadOnlyField(
                            label: 'Payment status',
                            value: widget.membership!.paymentLabel,
                            icon: Icons.payments_outlined,
                            note: 'Set from the row menu.',
                          ),
                        ),
                        const SizedBox(height: AdminTokens.space4),
                      ],
                      AdminSwitchField(
                        label: 'Auto renew',
                        value: _autoRenew,
                        enabled: !_saving,
                        onLabel: 'Renews automatically at the end of the term',
                        offLabel: 'Ends at the end of the term',
                        onChanged: (value) => setState(() => _autoRenew = value),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AdminFormFooter(
              saving: _saving,
              submitLabel: isEdit ? 'Save changes' : 'Create membership',
              onCancel: () => Navigator.of(context).pop(false),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// A read-only box that opens the platform date picker.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
    this.note,
  });

  final String label;
  final DateTime? value;
  final bool enabled;
  final VoidCallback onTap;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminFieldLabel(label, required: true),
        const SizedBox(height: AdminTokens.space2),
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AdminTokens.space4,
              vertical: AdminTokens.space3 + 2,
            ),
            decoration: BoxDecoration(
              color: tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
              border: Border.all(color: tokens.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 17,
                  color: tokens.textMuted,
                ),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Text(
                    value == null ? 'Select a date' : AdminFormat.date(value),
                    style: TextStyle(
                      color: value == null
                          ? tokens.textMuted
                          : tokens.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: tokens.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 5),
          Text(
            note!,
            style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
          ),
        ],
      ],
    );
  }
}
