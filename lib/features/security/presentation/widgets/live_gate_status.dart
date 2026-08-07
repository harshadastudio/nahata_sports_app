import 'package:flutter/material.dart';

import '../../../admin/domain/entities/visitor_pass.dart';
import '../../../admin/presentation/theme/admin_theme.dart';
import '../../../admin/presentation/widgets/admin_states.dart';

/// Who is inside the building right now.
///
/// This is the one panel that is deliberately not bound to the selected date
/// range: a visitor who entered before midnight and has not left is still
/// inside, and a gate desk that could not see them would be looking at a lie.
class LiveGateStatus extends StatelessWidget {
  const LiveGateStatus({
    super.key,
    required this.inside,
    required this.updatedAt,
    this.limit = 8,
    this.onSelect,
    this.onCheckOut,
  });

  final List<VisitorPass> inside;

  /// When the figures were last read, for the "live" pill.
  final DateTime? updatedAt;

  final int limit;

  final ValueChanged<VisitorPass>? onSelect;
  final ValueChanged<VisitorPass>? onCheckOut;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    if (inside.isEmpty) {
      return EmptyStateView(
        icon: Icons.door_front_door_outlined,
        title: 'The building is empty',
        message:
            'Nobody is checked in at the moment. Visitors appear here as soon '
            'as their pass is scanned at the gate.',
      );
    }

    final shown = inside.length > limit ? inside.sublist(0, limit) : inside;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _LivePill(updatedAt: updatedAt),
            const Spacer(),
            Text(
              '${inside.length} inside',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AdminTokens.space4),
        for (final pass in shown) ...[
          _GateRow(
            pass: pass,
            onTap: onSelect == null ? null : () => onSelect!(pass),
            onCheckOut: onCheckOut == null ? null : () => onCheckOut!(pass),
          ),
          if (pass != shown.last) const SizedBox(height: AdminTokens.space2),
        ],
        if (inside.length > limit)
          Padding(
            padding: const EdgeInsets.only(top: AdminTokens.space3),
            child: Text(
              '+ ${inside.length - limit} more inside',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _LivePill extends StatelessWidget {
  const _LivePill({required this.updatedAt});

  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final at = updatedAt;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.success,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            at == null
                ? 'Live'
                : 'Live · ${at.hour.toString().padLeft(2, '0')}:'
                    '${at.minute.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: tokens.success,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _GateRow extends StatelessWidget {
  const _GateRow({required this.pass, this.onTap, this.onCheckOut});

  final VisitorPass pass;
  final VoidCallback? onTap;
  final VoidCallback? onCheckOut;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AdminTokens.space3),
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: tokens.success.withValues(alpha: 0.16),
              child: Text(
                pass.initials,
                style: TextStyle(
                  color: tokens.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
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
                    pass.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  Text(
                    _since(pass.entryTime),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            if (onCheckOut != null)
              TextButton(
                onPressed: onCheckOut,
                style: TextButton.styleFrom(
                  foregroundColor: tokens.warning,
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Check out'),
              ),
          ],
        ),
      ),
    );
  }

  /// "In since 08:35" — and how long that has been, which is what tells a desk
  /// somebody has been on site far longer than they should be.
  static String _since(DateTime? entry) {
    if (entry == null) return 'Checked in';

    final clock = '${entry.hour.toString().padLeft(2, '0')}:'
        '${entry.minute.toString().padLeft(2, '0')}';
    final elapsed = DateTime.now().difference(entry);

    if (elapsed.isNegative) return 'In since $clock';
    if (elapsed.inMinutes < 60) return 'In since $clock · ${elapsed.inMinutes}m';
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes % 60;
    return 'In since $clock · ${hours}h ${minutes}m';
  }
}