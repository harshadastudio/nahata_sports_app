import 'package:flutter/material.dart';

import '../../../admin/domain/entities/visitor_pass.dart';
import '../../../admin/presentation/theme/admin_theme.dart';
import '../../../admin/presentation/widgets/admin_states.dart';
import '../../../admin/presentation/widgets/visitor_pass_status_chip.dart';

/// The passes issued most recently, with the QR code on each.
///
/// A desk that has just generated three passes for a group needs to hand the
/// right code to the right person; a strip of the last few, code visible, is
/// faster than searching for each of them.
class RecentPassesStrip extends StatelessWidget {
  const RecentPassesStrip({
    super.key,
    required this.passes,
    required this.loading,
    required this.onSelect,
    this.onGenerate,
  });

  final List<VisitorPass> passes;
  final bool loading;
  final ValueChanged<VisitorPass> onSelect;
  final VoidCallback? onGenerate;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 128,
        child: Row(
          children: [
            Expanded(child: ShimmerBox(height: 128)),
            SizedBox(width: AdminTokens.space3),
            Expanded(child: ShimmerBox(height: 128)),
            SizedBox(width: AdminTokens.space3),
            Expanded(child: ShimmerBox(height: 128)),
          ],
        ),
      );
    }

    if (passes.isEmpty) {
      return EmptyStateView(
        icon: Icons.badge_outlined,
        title: 'No passes generated yet',
        message:
            'Passes you issue in this period appear here, with their codes '
            'ready to hand over.',
        actionLabel: onGenerate == null ? null : 'Generate a pass',
        onAction: onGenerate,
      );
    }

    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: passes.length,
        separatorBuilder: (_, __) => const SizedBox(width: AdminTokens.space3),
        itemBuilder: (context, index) =>
            _PassCard(pass: passes[index], onTap: () => onSelect(passes[index])),
      ),
    );
  }
}

class _PassCard extends StatelessWidget {
  const _PassCard({required this.pass, required this.onTap});

  final VisitorPass pass;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(AdminTokens.space4),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
          border: Border.all(color: tokens.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pass.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                VisitorPassStatusChip(pass: pass, dense: true),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              (pass.visitPurpose ?? '').trim().isEmpty
                  ? 'Visitor'
                  : pass.visitPurpose!.trim(),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AdminTokens.space3,
                vertical: AdminTokens.space2 + 1,
              ),
              decoration: BoxDecoration(
                color: tokens.surfaceAlt,
                borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
                border: Border.all(color: tokens.border),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.qr_code_2_rounded,
                    size: 16,
                    color: tokens.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      (pass.passCode ?? '').trim().isEmpty
                          ? 'No code'
                          : pass.passCode!.trim(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}