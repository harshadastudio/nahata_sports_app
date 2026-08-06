import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/coupon.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'admin_form_fields.dart';
import 'glass_card.dart';

/// Runs `POST /coupons/validate` for a coupon against a trial amount.
///
/// This is the checkout call, made from the console: the server decides
/// whether the coupon applies and does the arithmetic, so an admin can see
/// exactly what a customer would get — including the rejection message they
/// would see — before anyone complains that a coupon "does not work".
class CouponValidateDialog extends StatefulWidget {
  const CouponValidateDialog({
    super.key,
    required this.coupon,
    required this.onValidate,
  });

  final AdminCoupon coupon;

  final Future<CouponCheck> Function({
    required String code,
    required num amount,
    required CouponAppliesTo appliesTo,
    int? sportComplexId,
    int? sportId,
    int? eventPassId,
  })
  onValidate;

  static Future<void> show(
    BuildContext context, {
    required AdminCoupon coupon,
    required Future<CouponCheck> Function({
      required String code,
      required num amount,
      required CouponAppliesTo appliesTo,
      int? sportComplexId,
      int? sportId,
      int? eventPassId,
    })
    onValidate,
  }) {
    AdminLog.ui('Validate dialog opened for ${coupon.displayCode}');

    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) =>
          CouponValidateDialog(coupon: coupon, onValidate: onValidate),
    );
  }

  @override
  State<CouponValidateDialog> createState() => _CouponValidateDialogState();
}

class _CouponValidateDialogState extends State<CouponValidateDialog> {
  final _amount = TextEditingController(text: '1000');

  bool _running = false;
  CouponCheck? _result;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_running) return;

    final amount = num.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter an amount to test against.');
      return;
    }

    setState(() {
      _running = true;
      _error = null;
      _result = null;
    });

    final coupon = widget.coupon;

    try {
      final check = await widget.onValidate(
        code: coupon.displayCode,
        amount: amount,
        // The coupon's own scope is what a customer would be checking out
        // under, so it is used rather than guessed.
        appliesTo: coupon.appliesTo ?? CouponAppliesTo.court,
        sportComplexId: coupon.sportComplexId,
        sportId: coupon.sportId,
        eventPassId: coupon.eventPassId,
      );

      if (!mounted) return;
      setState(() {
        _running = false;
        _result = check;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = error.message;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _error = 'Could not check this coupon. Please try again.';
      });
      AdminLog.failure(
        'Coupon validation crashed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final result = _result;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
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
                      Icons.calculate_outlined,
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
                          'Test ${widget.coupon.displayCode}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'Exactly what a customer would get',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: tokens.textMuted,
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: AdminTokens.space5),
              AdminTextField(
                controller: _amount,
                label: 'Booking amount (₹)',
                icon: Icons.currency_rupee_rounded,
                hint: 'e.g. 1000',
                enabled: !_running,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: AdminTokens.space4),
                AdminFormErrorBanner(message: _error!),
              ],
              if (result != null) ...[
                const SizedBox(height: AdminTokens.space4),
                _ResultCard(result: result),
              ],
              const SizedBox(height: AdminTokens.space5),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _running
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.textSecondary,
                    ),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: AdminTokens.space3),
                  FilledButton.icon(
                    onPressed: _running ? null : _run,
                    icon: _running
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Check'),
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

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final CouponCheck result;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final accent = result.isValid ? tokens.success : tokens.danger;

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      color: accent.withValues(alpha: 0.06),
      borderColor: accent.withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.isValid
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                size: 20,
                color: accent,
              ),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                child: Text(
                  result.isValid ? 'Coupon valid' : 'Coupon invalid',
                  style: TextStyle(
                    color: accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if ((result.message ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AdminTokens.space3),
            // The backend's own words — the customer would see this.
            Text(
              result.message!.trim(),
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ],
          if (result.isValid) ...[
            const SizedBox(height: AdminTokens.space4),
            _Amount('Order amount', result.originalAmount),
            _Amount('Discount', result.discountAmount, negative: true),
            Divider(color: tokens.border, height: AdminTokens.space5),
            _Amount('Payable', result.finalAmount, emphasise: true),
          ],
        ],
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount(
    this.label,
    this.value, {
    this.negative = false,
    this.emphasise = false,
  });

  final String label;
  final num? value;
  final bool negative;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    final text = value == null
        ? AdminFormat.dash
        : '${negative ? '- ' : ''}${AdminFormat.currency(value)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: emphasise ? tokens.textPrimary : tokens.textMuted,
                fontSize: emphasise ? 13.5 : 12.5,
                fontWeight: emphasise ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            text,
            style: TextStyle(
              color: negative ? tokens.success : tokens.textPrimary,
              fontSize: emphasise ? 15 : 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
