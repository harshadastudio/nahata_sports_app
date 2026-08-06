import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/coupon.dart';
import '../../domain/entities/event_pass.dart';
import '../../domain/entities/sport.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import '../utils/server_field_errors.dart';
import 'admin_form_fields.dart';

/// Create / edit a coupon.
///
/// [coupon] null means create (`POST /admin/coupons`), otherwise edit
/// (`PUT /admin/coupons/{id}`). The scope switch is the important part: a
/// coupon applies to a court booking **or** an event, never both, so choosing
/// one clears the other's fields rather than sending a body the server would
/// have to reject.
class CouponFormDialog extends StatefulWidget {
  const CouponFormDialog({
    super.key,
    required this.onSubmit,
    required this.onCheckCode,
    required this.complexes,
    required this.complexesState,
    required this.sports,
    required this.sportsState,
    required this.events,
    required this.eventsState,
    required this.onReloadOptions,
    this.coupon,
    this.allowedScopes = CouponAppliesTo.values,
    this.lockedComplexId,
  });

  final AdminCoupon? coupon;

  /// Throws on failure so this dialog can stay open and explain itself.
  final Future<void> Function(CouponDraft draft) onSubmit;

  /// Looks a code up before creating, so a duplicate is caught in the field
  /// rather than as a 409 after the fact. Null means the code is free.
  final Future<AdminCoupon?> Function(String code) onCheckCode;

  final List<SportsComplex> complexes;
  final ViewState complexesState;

  final List<Sport> sports;
  final ViewState sportsState;

  final List<AdminEventPass> events;
  final ViewState eventsState;

  final VoidCallback onReloadOptions;

  /// The scopes this account may issue coupons for — a complex admin gets
  /// Court only.
  final List<CouponAppliesTo> allowedScopes;

  /// Set for a complex admin: the one venue they may issue coupons for.
  final int? lockedComplexId;

  bool get isEdit => coupon != null;

  /// Resolves to true when a save succeeded.
  static Future<bool> show(
    BuildContext context, {
    AdminCoupon? coupon,
    required Future<void> Function(CouponDraft draft) onSubmit,
    required Future<AdminCoupon?> Function(String code) onCheckCode,
    required List<SportsComplex> complexes,
    required ViewState complexesState,
    required List<Sport> sports,
    required ViewState sportsState,
    required List<AdminEventPass> events,
    required ViewState eventsState,
    required VoidCallback onReloadOptions,
    List<CouponAppliesTo> allowedScopes = CouponAppliesTo.values,
    int? lockedComplexId,
  }) async {
    AdminLog.ui(
      '${coupon == null ? 'Add' : 'Edit'} coupon dialog opened'
      '${coupon == null ? '' : ' for ${coupon.id}'}',
    );

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => CouponFormDialog(
        coupon: coupon,
        onSubmit: onSubmit,
        onCheckCode: onCheckCode,
        complexes: complexes,
        complexesState: complexesState,
        sports: sports,
        sportsState: sportsState,
        events: events,
        eventsState: eventsState,
        onReloadOptions: onReloadOptions,
        allowedScopes: allowedScopes,
        lockedComplexId: lockedComplexId,
      ),
    );

    AdminLog.ui('Coupon dialog closed (saved: ${saved ?? false})');
    return saved ?? false;
  }

  @override
  State<CouponFormDialog> createState() => _CouponFormDialogState();
}

class _CouponFormDialogState extends State<CouponFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _code;
  late final TextEditingController _description;
  late final TextEditingController _discountValue;
  late final TextEditingController _maxDiscount;
  late final TextEditingController _usageLimit;

  CouponDiscountType? _discountType;
  CouponAppliesTo? _appliesTo;
  CouponPlatform? _platform;
  AdminUserStatus? _status;
  DateTime? _validUntil;

  SportsComplex? _complex;
  Sport? _sport;
  AdminEventPass? _event;

  bool _saving = false;
  bool _checkingCode = false;
  String? _error;
  ServerFieldErrors _fieldErrors = ServerFieldErrors.none;

  /// A code the lookup found already in use. Kept so the field can keep
  /// refusing it without asking the server again on every keystroke.
  String? _takenCode;

  @override
  void initState() {
    super.initState();
    final coupon = widget.coupon;

    _code = TextEditingController(text: coupon?.code ?? '');
    _description = TextEditingController(text: coupon?.description ?? '');
    _discountValue = TextEditingController(
      text: _numberText(coupon?.discountValue),
    );
    _maxDiscount = TextEditingController(
      text: _numberText(coupon?.maxDiscount),
    );
    _usageLimit = TextEditingController(
      text: coupon?.usageLimit?.toString() ?? '',
    );

    _discountType = coupon?.discountType ?? CouponDiscountType.percentage;
    _appliesTo = coupon?.appliesTo ?? widget.allowedScopes.first;
    _platform = coupon?.platform ?? CouponPlatform.all;
    _status = coupon?.status ?? AdminUserStatus.active;
    _validUntil = coupon?.validUntil;

    _complex = _matchComplex(coupon?.sportComplexId ?? widget.lockedComplexId);
    _sport = _matchSport(coupon?.sportId);
    _event = _matchEvent(coupon?.eventPassId);

    AdminLog.life(
      'CouponFormDialog mounted (${widget.isEdit ? 'edit' : 'create'})',
    );
  }

  @override
  void didUpdateWidget(covariant CouponFormDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The option lists may land after the dialog opened; preselect once they do.
    if (_complex == null) {
      final matched = _matchComplex(
        widget.coupon?.sportComplexId ?? widget.lockedComplexId,
      );
      if (matched != null) setState(() => _complex = matched);
    }
    if (_sport == null && widget.coupon?.sportId != null) {
      final matched = _matchSport(widget.coupon!.sportId);
      if (matched != null) setState(() => _sport = matched);
    }
    if (_event == null && widget.coupon?.eventPassId != null) {
      final matched = _matchEvent(widget.coupon!.eventPassId);
      if (matched != null) setState(() => _event = matched);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _code,
      _description,
      _discountValue,
      _maxDiscount,
      _usageLimit,
    ]) {
      controller.dispose();
    }
    AdminLog.life('CouponFormDialog disposed');
    super.dispose();
  }

  static String _numberText(num? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  SportsComplex? _matchComplex(int? id) {
    if (id == null) return null;
    for (final complex in widget.complexes) {
      if (complex.id == id) return complex;
    }
    return null;
  }

  Sport? _matchSport(int? id) {
    if (id == null) return null;
    for (final sport in widget.sports) {
      if (sport.id == id) return sport;
    }
    return null;
  }

  AdminEventPass? _matchEvent(int? id) {
    if (id == null) return null;
    for (final event in widget.events) {
      if (event.id == id) return event;
    }
    return null;
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

  bool get _isCourtScope => _appliesTo?.isCourt ?? true;

  bool get _complexLocked => widget.lockedComplexId != null;

  Future<void> _pickValidUntil() async {
    final now = DateTime.now();
    final current = _validUntil;

    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now.add(const Duration(days: 30)),
      // A coupon can be edited after it expired, so the range reaches back.
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 6),
      helpText: 'Coupon valid until',
    );
    if (picked == null || !mounted) return;

    setState(
      () => _validUntil = DateTime(picked.year, picked.month, picked.day),
    );
  }

  /// Asks the backend whether the typed code is already taken. Create only —
  /// an edit keeps its own code.
  Future<bool> _codeIsFree() async {
    if (widget.isEdit) return true;

    final code = _code.text.trim().toUpperCase();
    if (code.isEmpty) return true;

    setState(() => _checkingCode = true);
    try {
      final existing = await widget.onCheckCode(code);
      if (!mounted) return true;

      if (existing == null) {
        setState(() => _takenCode = null);
        return true;
      }

      setState(() => _takenCode = code);
      _formKey.currentState?.validate();
      return false;
    } catch (error) {
      // The lookup is a courtesy; if it fails, the create still goes ahead and
      // the server has the last word.
      AdminLog.failure('Coupon code lookup failed', error: error);
      return true;
    } finally {
      if (mounted) setState(() => _checkingCode = false);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      AdminLog.ui('Coupon form failed local validation');
      return;
    }

    if (_validUntil == null) {
      setState(() => _error = 'Pick the date the coupon expires.');
      return;
    }

    if (!await _codeIsFree()) return;
    if (!mounted) return;

    final scope = _appliesTo ?? CouponAppliesTo.court;

    final draft = CouponDraft(
      // The code identifies the coupon, so it is only sent on create.
      code: widget.isEdit ? null : _code.text,
      description: _description.text,
      discountType: _discountType,
      discountValue: num.tryParse(_discountValue.text.trim()),
      maxDiscount: num.tryParse(_maxDiscount.text.trim()),
      validUntil: _validUntil,
      usageLimit: int.tryParse(_usageLimit.text.trim()),
      status: _status,
      appliesTo: scope,
      platform: _platform,
      sportComplexId: scope.isCourt
          ? (_complex?.id ?? widget.lockedComplexId)
          : null,
      sportId: scope.isCourt ? _sport?.id : null,
      eventPassId: scope.isCourt ? null : _event?.id,
    );

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = ServerFieldErrors.none;
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
        _fieldErrors = parsed;
      });
      _formKey.currentState?.validate();
      AdminLog.failure('Coupon save rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this coupon. Please try again.';
      });
      AdminLog.failure(
        'Coupon save crashed',
        error: error,
        stackTrace: stackTrace,
      );
    }
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
          maxWidth: 620,
          maxHeight: size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminFormHeader(
              title: isEdit ? 'Edit coupon' : 'Create coupon',
              subtitle: isEdit
                  ? widget.coupon!.displayCode
                  : 'A discount customers can apply at checkout',
              icon: isEdit ? Icons.edit_outlined : Icons.local_offer_outlined,
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
                      const AdminFormSection(
                        icon: Icons.confirmation_number_outlined,
                        label: 'The coupon',
                        color: Color(0xFF3949AB),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminTextField(
                        controller: _code,
                        label: 'Coupon code',
                        icon: Icons.tag_rounded,
                        hint: 'e.g. WELCOME10',
                        required: !isEdit,
                        enabled: !_saving && !isEdit,
                        textCapitalization: TextCapitalization.characters,
                        // Codes are typed by customers, so nothing that would
                        // be ambiguous in a URL or a chat message is allowed.
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9_\-]'),
                          ),
                          LengthLimitingTextInputFormatter(32),
                        ],
                        suffix: _checkingCode
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                        onChanged: (_) {
                          // Typing past a rejection clears it.
                          if (_takenCode != null) {
                            setState(() => _takenCode = null);
                          }
                        },
                        validator: (value) {
                          final server = _fieldErrors.forKeys(const [
                            'code',
                            'couponCode',
                          ]);
                          if (server != null) return server;
                          if (isEdit) return null;

                          final text = (value ?? '').trim();
                          if (text.isEmpty) return 'Coupon code is required';
                          if (text.length < 3) {
                            return 'Use at least 3 characters';
                          }
                          if (_takenCode != null &&
                              text.toUpperCase() == _takenCode) {
                            return 'That code is already in use';
                          }
                          return null;
                        },
                      ),
                      if (isEdit) ...[
                        const SizedBox(height: AdminTokens.space2),
                        Text(
                          'The code cannot be changed once customers have it.',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: AdminTokens.space4),
                      AdminTextField(
                        controller: _description,
                        label: 'Description',
                        icon: Icons.notes_rounded,
                        hint: 'e.g. 10% off your first booking',
                        enabled: !_saving,
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (_) =>
                            _fieldErrors.forKeys(const ['description']),
                      ),
                      const SizedBox(height: AdminTokens.space5),
                      const AdminFormSection(
                        icon: Icons.percent_rounded,
                        label: 'The discount',
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminFieldPair(
                        narrow: narrow,
                        first: AdminVocabularyDropdown<CouponDiscountType>(
                          label: 'Discount type',
                          icon: Icons.sell_outlined,
                          value: _discountType,
                          required: true,
                          enabled: !_saving,
                          items: CouponDiscountType.values,
                          labelOf: (type) => type.label,
                          error: _fieldErrors.forKeys(const [
                            'discountType',
                            'discount_type',
                          ]),
                          onChanged: (type) =>
                              setState(() => _discountType = type),
                        ),
                        second: AdminTextField(
                          controller: _discountValue,
                          label: _discountType == CouponDiscountType.fixed
                              ? 'Discount amount (₹)'
                              : 'Discount percentage',
                          icon: _discountType == CouponDiscountType.fixed
                              ? Icons.currency_rupee_rounded
                              : Icons.percent_rounded,
                          hint: _discountType == CouponDiscountType.fixed
                              ? 'e.g. 200'
                              : 'e.g. 10',
                          required: true,
                          enabled: !_saving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            final server = _fieldErrors.forKeys(const [
                              'discountValue',
                              'discount_value',
                            ]);
                            if (server != null) return server;

                            final text = (value ?? '').trim();
                            if (text.isEmpty) return 'Enter the discount';
                            final parsed = num.tryParse(text);
                            if (parsed == null) return 'Enter a number';
                            if (parsed <= 0) return 'Must be more than zero';
                            if (_discountType ==
                                    CouponDiscountType.percentage &&
                                parsed > 100) {
                              return 'A percentage cannot exceed 100';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminFieldPair(
                        narrow: narrow,
                        first: AdminTextField(
                          controller: _maxDiscount,
                          label: 'Maximum discount (₹)',
                          icon: Icons.trending_up_rounded,
                          hint: 'Optional cap, e.g. 200',
                          // A cap only means something for a percentage.
                          enabled:
                              !_saving &&
                              _discountType != CouponDiscountType.fixed,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          validator: (value) {
                            final server = _fieldErrors.forKeys(const [
                              'maxDiscount',
                              'max_discount',
                            ]);
                            if (server != null) return server;

                            final text = (value ?? '').trim();
                            if (text.isEmpty) return null;
                            final parsed = num.tryParse(text);
                            if (parsed == null) return 'Enter a number';
                            if (parsed <= 0) return 'Must be more than zero';
                            return null;
                          },
                        ),
                        second: AdminTextField(
                          controller: _usageLimit,
                          label: 'Usage limit',
                          icon: Icons.repeat_rounded,
                          hint: 'Blank for unlimited',
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            final server = _fieldErrors.forKeys(const [
                              'usageLimit',
                              'usage_limit',
                            ]);
                            if (server != null) return server;

                            final text = (value ?? '').trim();
                            if (text.isEmpty) return null;
                            final parsed = int.tryParse(text);
                            if (parsed == null) return 'Enter a whole number';
                            if (parsed <= 0) return 'Must be at least 1';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminFieldPair(
                        narrow: narrow,
                        first: _DateField(
                          label: 'Valid until',
                          value: _validUntil,
                          enabled: !_saving,
                          onTap: _pickValidUntil,
                          error: _validUntil == null
                              ? null
                              : _fieldErrors.forKeys(const [
                                  'validUntil',
                                  'valid_until',
                                ]),
                          note: _validUntil == null
                              ? 'Required — the coupon stops working after this day'
                              : null,
                        ),
                        second: AdminStatusDropdown(
                          value: _status,
                          enabled: !_saving,
                          error: _fieldErrors.forKeys(const ['status']),
                          onChanged: (status) =>
                              setState(() => _status = status),
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space5),
                      const AdminFormSection(
                        icon: Icons.tune_rounded,
                        label: 'Where it applies',
                        color: Color(0xFF8B5CF6),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminFieldPair(
                        narrow: narrow,
                        first: AdminVocabularyDropdown<CouponAppliesTo>(
                          label: 'Applies to',
                          icon: Icons.category_outlined,
                          value: _appliesTo,
                          required: true,
                          enabled: !_saving && widget.allowedScopes.length > 1,
                          items: widget.allowedScopes,
                          labelOf: (scope) => scope.label,
                          error: _fieldErrors.forKeys(const [
                            'appliesTo',
                            'applies_to',
                          ]),
                          onChanged: (scope) => setState(() {
                            _appliesTo = scope;
                            // One scope only: switching drops whatever the
                            // other side had selected.
                            if (scope?.isCourt ?? true) {
                              _event = null;
                            } else {
                              _sport = null;
                              if (!_complexLocked) _complex = null;
                            }
                          }),
                        ),
                        second: AdminVocabularyDropdown<CouponPlatform>(
                          label: 'Platform',
                          icon: Icons.devices_rounded,
                          value: _platform,
                          required: true,
                          enabled: !_saving,
                          items: CouponPlatform.values,
                          labelOf: (platform) => platform.label,
                          error: _fieldErrors.forKeys(const ['platform']),
                          onChanged: (platform) =>
                              setState(() => _platform = platform),
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      if (_isCourtScope) ...[
                        AdminCatalogueDropdown<SportsComplex>(
                          label: 'Sport complex',
                          icon: Icons.stadium_outlined,
                          options: widget.complexes,
                          value: _complex,
                          labelOf: (complex) => complex.label,
                          idOf: (complex) => complex.id,
                          state: widget.complexesState,
                          onReload: widget.onReloadOptions,
                          enabled: !_saving && !_complexLocked,
                          error: _fieldErrors.forKeys(const [
                            'sportComplexId',
                            'sport_complex_id',
                          ]),
                          note: _complexLocked
                              ? 'Coupons you create apply to your own complex.'
                              : 'Leave blank to let the coupon work at every '
                                    'complex.',
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
                          error: _fieldErrors.forKeys(const [
                            'sportId',
                            'sport_id',
                          ]),
                          note: 'Leave blank to cover every sport.',
                          onChanged: (sport) => setState(() => _sport = sport),
                        ),
                      ] else ...[
                        AdminCatalogueDropdown<AdminEventPass>(
                          label: 'Event pass',
                          icon: Icons.confirmation_number_outlined,
                          options: widget.events,
                          value: _event,
                          labelOf: (event) =>
                              event.title ?? 'Event ${event.id}',
                          idOf: (event) => event.id,
                          state: widget.eventsState,
                          onReload: widget.onReloadOptions,
                          enabled: !_saving,
                          error: _fieldErrors.forKeys(const [
                            'eventPassId',
                            'event_pass_id',
                          ]),
                          note: 'Leave blank to cover every event.',
                          onChanged: (event) => setState(() => _event = event),
                        ),
                      ],
                      const SizedBox(height: AdminTokens.space4),
                      AdminFormNote(
                        icon: Icons.info_outline_rounded,
                        text: _isCourtScope
                            ? 'This coupon can only be used on court bookings. '
                                  'Platform decides where it works: the backend '
                                  'checks it against the app or web request.'
                            : 'This coupon can only be used on event passes. '
                                  'Platform decides where it works: the backend '
                                  'checks it against the app or web request.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AdminFormFooter(
              saving: _saving || _checkingCode,
              submitLabel: isEdit ? 'Save changes' : 'Create coupon',
              onCancel: _saving ? null : () => Navigator.of(context).pop(false),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// A tap-to-pick date, styled like the other fields in the form.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
    this.note,
    this.error,
  });

  final String label;
  final DateTime? value;
  final bool enabled;
  final VoidCallback onTap;
  final String? note;
  final String? error;

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
              border: Border.all(
                color: error != null ? tokens.danger : tokens.border,
              ),
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
        if (error != null) ...[
          const SizedBox(height: 5),
          Text(error!, style: TextStyle(color: tokens.danger, fontSize: 11.5)),
        ] else if (note != null) ...[
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
