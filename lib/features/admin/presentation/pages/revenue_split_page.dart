import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/revenue_split.dart';
import '../navigation/admin_module.dart';
import '../state/revenue_split_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/admin_states.dart';
import '../widgets/glass_card.dart';
import '../widgets/revenue_split_backfill_dialog.dart';
import '../widgets/revenue_split_check_dialog.dart';
import '../widgets/revenue_split_form_dialog.dart';

/// Coaching Revenue > Revenue Split. ADMIN (super admin) only — the backend
/// refuses even COMPLEX_ADMIN and EMPLOYEE on the reads, which is why this
/// module is wired only into [AdminShellConfig.admin], never the
/// COMPLEX_ADMIN shell.
class RevenueSplitPage extends StatefulWidget {
  const RevenueSplitPage({super.key});

  @override
  State<RevenueSplitPage> createState() => _RevenueSplitPageState();
}

class _RevenueSplitPageState extends State<RevenueSplitPage> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    AdminLog.life('RevenueSplitPage mounted');
    final controller = context.read<RevenueSplitController>();
    _search = TextEditingController(text: controller.search);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.state.isIdle) controller.load();
      controller.loadOptions();
      controller.loadCoverage();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    AdminLog.life('RevenueSplitPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RevenueSplitController>();
    final tokens = AdminTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < AdminTokens.mobileMax;

    if (_search.text != controller.search) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _search.text == controller.search) return;
        _search.value = TextEditingValue(
          text: controller.search,
          selection: TextSelection.collapsed(offset: controller.search.length),
        );
      });
    }

    return ColoredBox(
      color: tokens.canvas,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? AdminTokens.space4 : AdminTokens.space6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Toolbar(
              controller: controller,
              searchController: _search,
              onAdd: AdminAccess.canCreate(AdminModules.revenueSplits)
                  ? () => _openForm(context, controller)
                  : null,
              onCheckBatch: () => _openCheckBatch(context, controller),
            ),
            const SizedBox(height: AdminTokens.space4),
            _CoverageBanner(
              controller: controller,
              onOpenWizard: () => _openBackfillWizard(context, controller),
            ),
            const SizedBox(height: AdminTokens.space4),
            Expanded(
              child: SolidCard(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RefreshLine(visible: controller.isRefreshing),
                      Expanded(
                        child: _Body(
                          controller: controller,
                          isMobile: isMobile,
                          onEdit: (rule) => _openForm(context, controller, rule: rule),
                          onToggle: (rule) => _toggle(context, controller, rule),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    RevenueSplitController controller,
    RevenueSplitRule rule,
  ) async {
    if (rule.isActive) {
      final confirmed = await ConfirmDialog.show(
        context,
        title: 'Deactivate this rule?',
        message:
            'Future payments for ${rule.targetLabel} fall through to the next '
            'matching rule, or to 100% Nahata if none exists. Money already '
            'collected keeps its recorded split.',
        confirmLabel: 'Deactivate',
        destructive: true,
      );
      if (!confirmed || !context.mounted) return;
    }

    final error = await controller.setActive(rule, !rule.isActive);
    if (!context.mounted) return;

    if (error != null) {
      AdminFeedback.error(context, error);
    } else {
      AdminFeedback.success(
        context,
        rule.isActive ? 'Rule deactivated.' : 'Rule reactivated.',
      );
    }
  }

  Future<void> _openForm(
    BuildContext context,
    RevenueSplitController controller, {
    RevenueSplitRule? rule,
  }) async {
    if (controller.options.sports.isEmpty && !controller.optionsState.isLoading) {
      await controller.loadOptions();
    }
    if (!context.mounted) return;

    final saved = await RevenueSplitFormDialog.show(
      context,
      rule: rule,
      options: controller.options,
      optionsState: controller.optionsState,
      onReloadOptions: () => controller.loadOptions(refresh: true),
      onSubmit: (draft) async {
        if (rule == null) {
          await controller.create(draft);
        } else {
          await controller.update(rule.id, draft);
        }
      },
    );

    if (!saved || !context.mounted) return;

    final affected = controller.lastAffectedExistingPayments;
    AdminFeedback.success(
      context,
      rule == null
          ? 'Rule created.'
          : 'Changes saved.'
                '${affected == null || affected == 0 ? '' : ' $affected existing payment(s) keep their old split.'}',
    );
  }

  Future<void> _openCheckBatch(
    BuildContext context,
    RevenueSplitController controller,
  ) async {
    if (controller.options.batches.isEmpty && !controller.optionsState.isLoading) {
      await controller.loadOptions();
    }
    if (!context.mounted) return;

    await RevenueSplitCheckDialog.show(
      context,
      options: controller.options,
      optionsState: controller.optionsState,
      onReloadOptions: () => controller.loadOptions(refresh: true),
      onCheck: controller.checkBatch,
    );
  }

  Future<void> _openBackfillWizard(
    BuildContext context,
    RevenueSplitController controller,
  ) {
    return RevenueSplitBackfillDialog.show(context, controller: controller);
  }
}

// -----------------------------------------------------------------------------
// Toolbar
// -----------------------------------------------------------------------------

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.searchController,
    required this.onAdd,
    required this.onCheckBatch,
  });

  final RevenueSplitController controller;
  final TextEditingController searchController;
  final VoidCallback? onAdd;
  final VoidCallback onCheckBatch;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < AdminTokens.tabletMax;

    final search = SizedBox(
      width: narrow ? double.infinity : 300,
      child: TextField(
        controller: searchController,
        onChanged: controller.onSearchChanged,
        style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search target, complex or notes',
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: tokens.textMuted),
          suffixIcon: controller.search.isEmpty
              ? null
              : IconButton(
                  onPressed: controller.clearSearch,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: tokens.textMuted,
                  tooltip: 'Clear',
                ),
        ),
      ),
    );

    final scopeFilter = Wrap(
      spacing: AdminTokens.space2,
      children: [
        for (final scope in <RevenueSplitScope?>[
          null,
          ...RevenueSplitScope.values,
        ])
          ChoiceChip(
            label: Text(scope == null ? 'All scopes' : scope.label),
            labelStyle: const TextStyle(fontSize: 12.5),
            selected: controller.scopeFilter == scope,
            onSelected: controller.state.isLoading
                ? null
                : (_) => controller.setScopeFilter(
                    controller.scopeFilter == scope ? null : scope,
                  ),
          ),
      ],
    );

    final showInactive = FilterChip(
      label: const Text('Show inactive'),
      labelStyle: const TextStyle(fontSize: 12.5),
      selected: controller.includeInactive,
      onSelected: controller.state.isLoading
          ? null
          : (value) => controller.setIncludeInactive(value),
    );

    final checkBatch = OutlinedButton.icon(
      onPressed: onCheckBatch,
      icon: const Icon(Icons.fact_check_outlined, size: 18),
      label: const Text('Check a batch'),
    );

    final refresh = OutlinedButton.icon(
      onPressed: controller.state.isLoading ? null : controller.refresh,
      icon: controller.state.isLoading
          ? const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_rounded, size: 18),
      label: const Text('Refresh'),
    );

    final add = onAdd == null
        ? const SizedBox.shrink()
        : FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('New rule'),
          );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Revenue Split',
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AdminTokens.space3),
          search,
          const SizedBox(height: AdminTokens.space3),
          Wrap(
            spacing: AdminTokens.space2,
            runSpacing: AdminTokens.space2,
            children: [scopeFilter, showInactive],
          ),
          const SizedBox(height: AdminTokens.space3),
          Row(
            children: [
              Expanded(child: checkBatch),
              const SizedBox(width: AdminTokens.space3),
              Expanded(child: refresh),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          add,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Revenue Split',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            search,
            const SizedBox(width: AdminTokens.space3),
            checkBatch,
            const SizedBox(width: AdminTokens.space3),
            refresh,
            const SizedBox(width: AdminTokens.space3),
            add,
          ],
        ),
        const SizedBox(height: AdminTokens.space3),
        Row(
          children: [
            Expanded(child: scopeFilter),
            const SizedBox(width: AdminTokens.space3),
            showInactive,
          ],
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Coverage banner
// -----------------------------------------------------------------------------

class _CoverageBanner extends StatelessWidget {
  const _CoverageBanner({required this.controller, required this.onOpenWizard});

  final RevenueSplitController controller;
  final VoidCallback onOpenWizard;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    if (controller.coverageState.isLoading) {
      return const SolidCard(
        padding: EdgeInsets.all(AdminTokens.space4),
        child: SizedBox(
          height: 18,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (controller.coverageState.isFailed) {
      return SolidCard(
        padding: const EdgeInsets.all(AdminTokens.space4),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, size: 18, color: tokens.textMuted),
            const SizedBox(width: AdminTokens.space3),
            Expanded(
              child: Text(
                'Could not check historical-backfill coverage.',
                style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
              ),
            ),
            TextButton(onPressed: controller.loadCoverage, child: const Text('Retry')),
          ],
        ),
      );
    }

    final coverage = controller.coverage;
    if (!controller.coverageState.isReady) return const SizedBox.shrink();

    final clear = coverage.clear;
    final color = clear ? tokens.success : tokens.warning;

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      color: color.withValues(alpha: 0.08),
      borderColor: color.withValues(alpha: 0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            clear ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            size: 20,
            color: color,
          ),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  clear
                      ? 'All ${coverage.summary.enrolments} paid enrolment(s) '
                            'resolve to a rule.'
                      : '${coverage.gaps.length} batch(es) have collected money '
                            'with no matching rule '
                            '(${AdminFormat.currency(coverage.uncoveredAmount)} uncovered).',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (coverage.summary.pending > 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${coverage.summary.pending} payment(s) have not been '
                    'backfilled into the historical ledger yet.',
                    style: TextStyle(color: tokens.textSecondary, fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AdminTokens.space3),
          OutlinedButton(
            onPressed: onOpenWizard,
            child: const Text('Open backfill wizard'),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Body
// -----------------------------------------------------------------------------

class _Body extends StatelessWidget {
  const _Body({
    required this.controller,
    required this.isMobile,
    required this.onEdit,
    required this.onToggle,
  });

  final RevenueSplitController controller;
  final bool isMobile;
  final ValueChanged<RevenueSplitRule> onEdit;
  final ValueChanged<RevenueSplitRule> onToggle;

  @override
  Widget build(BuildContext context) {
    if (controller.isFirstLoad) {
      return SingleChildScrollView(child: TableShimmer(rows: 7, dense: isMobile));
    }

    if (controller.state.isFailed && controller.rules.isEmpty) {
      return ErrorStateView(
        title: 'Could not load the rules',
        message: controller.error ?? 'Check your connection and try again.',
        onRetry: controller.refresh,
      );
    }

    final rules = controller.rules;

    if (rules.isEmpty) {
      return controller.hasFilters
          ? EmptyStateView(
              icon: Icons.search_off_rounded,
              title: 'No rules match this search',
              message: 'Try different terms, or clear the filters.',
              actionLabel: 'Clear filters',
              onAction: controller.clearSearch,
            )
          : const EmptyStateView(
              icon: Icons.percent_rounded,
              title: 'No revenue split rules yet',
              message:
                  'Create one so a coach\'s share of a payment is worked out '
                  'automatically instead of everything defaulting to Nahata.',
            );
    }

    if (isMobile) {
      return ListView.builder(
        padding: const EdgeInsets.all(AdminTokens.space3),
        itemCount: rules.length,
        itemBuilder: (context, index) =>
            _RuleCard(rule: rules[index], onEdit: onEdit, onToggle: onToggle),
      );
    }

    return SingleChildScrollView(
      child: _RulesTable(rules: rules, onEdit: onEdit, onToggle: onToggle),
    );
  }
}

class _RulesTable extends StatelessWidget {
  const _RulesTable({required this.rules, required this.onEdit, required this.onToggle});

  final List<RevenueSplitRule> rules;
  final ValueChanged<RevenueSplitRule> onEdit;
  final ValueChanged<RevenueSplitRule> onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 42,
        dataRowMinHeight: 52,
        dataRowMaxHeight: 64,
        columns: const [
          DataColumn(label: Text('Scope')),
          DataColumn(label: Text('Target')),
          DataColumn(label: Text('Complex')),
          DataColumn(label: Text('Split')),
          DataColumn(label: Text('Effective from')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('')),
        ],
        rows: rules.map((rule) {
          return DataRow(
            cells: [
              DataCell(Text(rule.scopeLabel)),
              DataCell(Text(rule.targetLabel)),
              DataCell(Text(rule.complexLabel)),
              DataCell(Text(rule.splitLabel)),
              DataCell(Text(AdminFormat.date(rule.effectiveFrom))),
              DataCell(_ActiveChip(active: rule.isActive)),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => onEdit(rule),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit',
                      color: tokens.textMuted,
                    ),
                    IconButton(
                      onPressed: () => onToggle(rule),
                      icon: Icon(
                        rule.isActive
                            ? Icons.pause_circle_outline_rounded
                            : Icons.play_circle_outline_rounded,
                        size: 18,
                      ),
                      tooltip: rule.isActive ? 'Deactivate' : 'Reactivate',
                      color: rule.isActive ? tokens.warning : tokens.success,
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.rule, required this.onEdit, required this.onToggle});

  final RevenueSplitRule rule;
  final ValueChanged<RevenueSplitRule> onEdit;
  final ValueChanged<RevenueSplitRule> onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      margin: const EdgeInsets.only(bottom: AdminTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rule.targetLabel,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _ActiveChip(active: rule.isActive),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${rule.scopeLabel} · ${rule.complexLabel}',
            style: TextStyle(color: tokens.textMuted, fontSize: 12),
          ),
          const SizedBox(height: AdminTokens.space3),
          Row(
            children: [
              Expanded(
                child: Text(
                  rule.splitLabel,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'From ${AdminFormat.date(rule.effectiveFrom)}',
                style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onEdit(rule),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
              ),
              const SizedBox(width: AdminTokens.space2),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onToggle(rule),
                  icon: Icon(
                    rule.isActive
                        ? Icons.pause_circle_outline_rounded
                        : Icons.play_circle_outline_rounded,
                    size: 16,
                  ),
                  label: Text(rule.isActive ? 'Deactivate' : 'Reactivate'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final color = active ? tokens.success : tokens.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space3,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
