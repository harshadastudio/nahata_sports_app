import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_coupon.dart';
import '../state/employee_coupons_controller.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_forms.dart';
import '../widgets/employee_list_scaffold.dart';

/// Employee → Coupons. The discount codes for this complex.
class EmployeeCouponsPage extends StatefulWidget {
  const EmployeeCouponsPage({super.key});

  @override
  State<EmployeeCouponsPage> createState() => _EmployeeCouponsPageState();
}

class _EmployeeCouponsPageState extends State<EmployeeCouponsPage> {
  late final EmployeeCouponsController _controller =
      EmployeeCouponsController(EmployeeDashboardRepositoryImpl());
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => EmployeeListScaffold<EmployeeCoupon>(
        title: 'Coupons',
        controller: _controller,
        subtitle: () => '${_controller.total} coupon'
            '${_controller.total == 1 ? '' : 's'}',
        scopeNotice: 'Discount codes for your own complex.',
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(null),
          backgroundColor: EmployeeTokens.brand,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New coupon'),
        ),
        filters: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EmployeeSearchBar(
              controller: _search,
              hintText: 'Search by code or description',
              onChanged: _controller.onSearchChanged,
              onClear: () => _controller.onSearchChanged(''),
            ),
            const SizedBox(height: EmployeeTokens.space3),
            EmployeeFilterChips<String>(
              values: EmployeeCouponsController.statuses,
              selected: _controller.status,
              labelOf: (s) => s,
              onChanged: _controller.setStatus,
            ),
          ],
        ),
        itemBuilder: (context, coupon) => _couponCard(coupon),
        emptyIcon: Icons.local_offer_outlined,
        emptyTitle: 'No coupons yet',
        emptyMessage: _controller.isFiltered
            ? 'Nothing matches these filters.'
            : 'Create a code and it will be redeemable at your complex.',
      ),
    );
  }

  Widget _couponCard(EmployeeCoupon coupon) {
    // The card is coloured by what the coupon *does* right now, not by the
    // stored status: an Active code that has expired or run out is not usable,
    // and colouring it green would say the opposite.
    final tone = coupon.isRedeemable
        ? EmployeeTokens.success
        : (coupon.isExpired || coupon.isExhausted
            ? EmployeeTokens.warning
            : EmployeeTokens.textMuted);

    return EmployeeCard(
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space3),
      accentColor: tone,
      onTap: () => _openForm(coupon),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coupon.displayCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        fontFamily: 'monospace',
                        color: EmployeeTokens.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      coupon.discountLabel,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: EmployeeTokens.textBody,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: EmployeeTokens.space2),
              EmployeeChip(
                label: coupon.effectiveStatus,
                color: tone,
                dense: true,
              ),
              IconButton(
                onPressed: () => _delete(coupon),
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
                color: EmployeeTokens.danger,
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if ((coupon.description ?? '').isNotEmpty) ...[
            const SizedBox(height: EmployeeTokens.space2),
            Text(
              coupon.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: EmployeeTokens.textMuted,
              ),
            ),
          ],
          const SizedBox(height: EmployeeTokens.space3),
          Wrap(
            spacing: EmployeeTokens.space2,
            runSpacing: EmployeeTokens.space2,
            children: [
              EmployeeChip(
                label: 'Till ${coupon.validUntilLabel}',
                color: coupon.isExpired
                    ? EmployeeTokens.danger
                    : EmployeeTokens.info,
                icon: Icons.event_outlined,
                dense: true,
              ),
              EmployeeChip(
                label: coupon.usageLabel,
                color: coupon.isExhausted
                    ? EmployeeTokens.danger
                    : EmployeeTokens.textMuted,
                icon: Icons.confirmation_number_outlined,
                dense: true,
              ),
              EmployeeChip(
                label: coupon.appliesTo,
                color: EmployeeTokens.purple,
                dense: true,
              ),
              if (coupon.platform.toLowerCase() != 'all')
                EmployeeChip(
                  label: '${coupon.platform} only',
                  color: EmployeeTokens.accent,
                  dense: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _delete(EmployeeCoupon coupon) async {
    final ok = await confirmEmployeeAction(
      context,
      title: 'Delete ${coupon.displayCode}?',
      message: 'Anyone who has the code will no longer be able to redeem it. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;

    final error = await _controller.delete(coupon);
    if (!mounted) return;

    showEmployeeToast(
      context,
      error ?? 'Coupon deleted',
      isError: error != null,
    );
  }

  Future<void> _openForm(EmployeeCoupon? coupon) async {
    // The form seeds every field once, at construction, so an edit re-reads the
    // coupon *before* the sheet opens rather than after. A failed read falls
    // back to the row already on screen — it is better to edit a slightly stale
    // coupon than to be unable to edit at all.
    final seed = coupon == null
        ? null
        : (await _controller.loadCoupon(coupon.id) ?? coupon);
    if (!mounted) return;

    await showEmployeeSheet<void>(
      context: context,
      title: seed == null ? 'New coupon' : 'Edit coupon',
      subtitle: seed?.displayCode,
      builder: (context) => _CouponForm(coupon: seed, controller: _controller),
    );
  }
}

class _CouponForm extends StatefulWidget {
  const _CouponForm({required this.coupon, required this.controller});

  final EmployeeCoupon? coupon;
  final EmployeeCouponsController controller;

  @override
  State<_CouponForm> createState() => _CouponFormState();
}

class _CouponFormState extends State<_CouponForm> {
  late final TextEditingController _code =
      TextEditingController(text: widget.coupon?.code ?? '');
  late final TextEditingController _value = TextEditingController(
    text: widget.coupon?.discountValue.toString() ?? '',
  );
  late final TextEditingController _maxDiscount = TextEditingController(
    text: widget.coupon?.maxDiscount?.toString() ?? '',
  );
  late final TextEditingController _description =
      TextEditingController(text: widget.coupon?.description ?? '');
  late final TextEditingController _usageLimit = TextEditingController(
    text: widget.coupon?.usageLimit?.toString() ?? '',
  );

  late String _discountType =
      EmployeeCouponDraft.discountTypes.contains(widget.coupon?.discountType)
          ? widget.coupon!.discountType
          : EmployeeCouponDraft.discountTypes.first;

  late String _status = EmployeeCouponDraft.statuses.contains(
    widget.coupon?.status,
  )
      ? widget.coupon!.status
      : EmployeeCouponDraft.statuses.first;

  late String _appliesTo =
      EmployeeCouponDraft.appliesToOptions.contains(widget.coupon?.appliesTo)
          ? widget.coupon!.appliesTo
          : EmployeeCouponDraft.appliesToOptions.first;

  late String _platform =
      EmployeeCouponDraft.platforms.contains(widget.coupon?.platform)
          ? widget.coupon!.platform
          : EmployeeCouponDraft.platforms.first;

  late DateTime? _validUntil = widget.coupon?.validUntil;

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.coupon != null;

  bool get _isPercentage => _discountType.toLowerCase() == 'percentage';

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    _maxDiscount.dispose();
    _description.dispose();
    _usageLimit.dispose();
    super.dispose();
  }

  EmployeeCouponDraft _draft() => EmployeeCouponDraft(
        code: _code.text,
        discountType: _discountType,
        discountValue: num.tryParse(_value.text.trim()),
        maxDiscount: num.tryParse(_maxDiscount.text.trim()),
        description: _description.text,
        validUntil: _validUntil,
        usageLimit: int.tryParse(_usageLimit.text.trim()),
        status: _status,
        appliesTo: _appliesTo,
        platform: _platform,
        isEdit: _isEdit,
      );

  Future<void> _save() async {
    final draft = _draft();

    final invalid = draft.validationError;
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = _isEdit
        ? await widget.controller.update(widget.coupon!.id, draft)
        : await widget.controller.create(draft);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }

    Navigator.of(context).pop();
    showEmployeeToast(context, _isEdit ? 'Coupon updated' : 'Coupon created');
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmployeeFormError(message: _error),

        EmployeeField(
          label: 'Code',
          required: !_isEdit,
          hint: _isEdit
              ? 'A code cannot be changed once the coupon exists.'
              : 'Stored in capitals, and must be unique.',
          child: EmployeeTextField(
            controller: _code,
            enabled: !_isEdit,
            textCapitalization: TextCapitalization.characters,
            hintText: 'e.g. FIRST20',
          ),
        ),

        EmployeeField(
          label: 'Discount type',
          child: EmployeeDropdown<String>(
            value: _discountType,
            items: EmployeeCouponDraft.discountTypes,
            labelOf: (t) => t,
            onChanged: (value) =>
                setState(() => _discountType = value ?? _discountType),
          ),
        ),

        EmployeeField(
          label: _isPercentage ? 'Discount (%)' : 'Discount amount',
          required: true,
          child: EmployeeNumberField(
            controller: _value,
            isCurrency: !_isPercentage,
            hintText: _isPercentage ? 'e.g. 20' : 'e.g. 100',
          ),
        ),

        // Only a percentage discount can be capped — a flat ₹100 off is already
        // its own maximum, and the API ignores the field for it.
        if (_isPercentage)
          EmployeeField(
            label: 'Maximum discount',
            hint: 'The most this coupon can take off. Leave blank for no cap.',
            child: EmployeeNumberField(
              controller: _maxDiscount,
              isCurrency: true,
              hintText: 'No cap',
            ),
          ),

        EmployeeField(
          label: 'Valid until',
          required: true,
          child: EmployeeDateField(
            value: _validUntil,
            firstDate: DateTime(now.year - 1),
            lastDate: DateTime(now.year + 5),
            onChanged: (value) => setState(() => _validUntil = value),
          ),
        ),

        EmployeeField(
          label: 'Usage limit',
          hint: 'Total redemptions allowed. Leave blank for unlimited.',
          child: EmployeeNumberField(
            controller: _usageLimit,
            allowDecimal: false,
            hintText: 'Unlimited',
          ),
        ),

        EmployeeField(
          label: 'Applies to',
          child: EmployeeDropdown<String>(
            value: _appliesTo,
            items: EmployeeCouponDraft.appliesToOptions,
            labelOf: (a) => a,
            onChanged: (value) =>
                setState(() => _appliesTo = value ?? _appliesTo),
          ),
        ),

        EmployeeField(
          label: 'Platform',
          hint: 'Where the code may be redeemed.',
          child: EmployeeDropdown<String>(
            value: _platform,
            items: EmployeeCouponDraft.platforms,
            labelOf: (p) => p,
            onChanged: (value) =>
                setState(() => _platform = value ?? _platform),
          ),
        ),

        EmployeeField(
          label: 'Description',
          child: EmployeeTextField(
            controller: _description,
            maxLines: 3,
            hintText: 'What the offer is',
          ),
        ),

        EmployeeField(
          label: 'Status',
          child: EmployeeDropdown<String>(
            value: _status,
            items: EmployeeCouponDraft.statuses,
            labelOf: (s) => s,
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
        ),

        EmployeeSheetActions(
          saving: _saving,
          saveLabel: _isEdit ? 'Update coupon' : 'Create coupon',
          onSave: _save,
        ),
      ],
    );
  }
}
