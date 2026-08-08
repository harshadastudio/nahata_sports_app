import 'package:flutter/material.dart';

import '../state/employee_collection_controller.dart';
import '../state/employee_view_state.dart';
import '../theme/employee_theme.dart';
import 'employee_states.dart';

/// The page the operations masters are built from.
///
/// The counterpart to `EmployeeListScaffold` for the collections that are not
/// paginated: same chrome, no scroll-to-load. Every one of these screens is
/// complex-scoped, so the scope notice is on by default rather than opt-in.
class EmployeeCollectionScaffold<T> extends StatelessWidget {
  const EmployeeCollectionScaffold({
    super.key,
    required this.title,
    required this.controller,
    required this.itemBuilder,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    this.subtitle,
    this.toolbar,
    this.onAdd,
    this.addLabel = 'Add',
    this.scopeNotice,
    this.emptyActionLabel,
  });

  final String title;

  /// A count under the title. Rebuilt with the controller.
  final String Function()? subtitle;

  final EmployeeCollectionController<T> controller;
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// A picker or filter pinned above the list — the court selector on Slots.
  final Widget? toolbar;

  /// Null hides the add button entirely, for a screen whose prerequisite is
  /// missing (no sport yet, so no court can be added).
  final VoidCallback? onAdd;
  final String addLabel;

  final String? scopeNotice;

  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;

  /// Offers the add action straight from the empty state — the most likely
  /// next move when a list is empty is to put something in it.
  final String? emptyActionLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EmployeeTokens.canvas,
      floatingActionButton: onAdd == null
          ? null
          : FloatingActionButton.extended(
              onPressed: onAdd,
              backgroundColor: EmployeeTokens.brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text(addLabel),
            ),
      appBar: AppBar(
        backgroundColor: EmployeeTokens.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        // Clamped for the same reason as `EmployeeListScaffold` — two stacked
        // lines do not fit a 56dp toolbar past ~1.3× text scale.
        title: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final text = subtitle?.call();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if ((text ?? '').isNotEmpty)
                    Text(
                      text!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.white70,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) => IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: controller.refreshing ? null : controller.refresh,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, _) =>
                EmployeeRefreshLine(visible: controller.refreshing),
          ),
        ),
      ),
      body: Column(
        children: [
          if (toolbar != null)
            Container(
              width: double.infinity,
              color: EmployeeTokens.surface,
              padding: const EdgeInsets.fromLTRB(
                EmployeeTokens.space4,
                EmployeeTokens.space3,
                EmployeeTokens.space4,
                EmployeeTokens.space3,
              ),
              child: toolbar,
            ),
          Expanded(
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => RefreshIndicator(
                color: EmployeeTokens.brand,
                onRefresh: controller.refresh,
                child: _body(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (controller.isInitialLoad) {
      return ListView(
        padding: const EdgeInsets.all(EmployeeTokens.space4),
        children: const [EmployeeListShimmer(rows: 4)],
      );
    }

    if (controller.state.isFailed && controller.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: EmployeeTokens.space8),
          EmployeeErrorView(
            message: controller.error ?? 'That did not load.',
            onRetry: controller.load,
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        EmployeeTokens.space4,
        EmployeeTokens.space4,
        EmployeeTokens.space4,
        // Clears the floating action button.
        EmployeeTokens.space8 * 2,
      ),
      children: [
        EmployeeScopeNotice(message: scopeNotice),
        const SizedBox(height: EmployeeTokens.space4),
        if (controller.items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: EmployeeTokens.space5),
            child: EmployeeEmptyView(
              icon: emptyIcon,
              title: emptyTitle,
              message: emptyMessage,
              actionLabel: onAdd == null ? null : emptyActionLabel,
              onAction: onAdd,
            ),
          )
        else
          for (final item in controller.items) itemBuilder(context, item),
      ],
    );
  }
}
