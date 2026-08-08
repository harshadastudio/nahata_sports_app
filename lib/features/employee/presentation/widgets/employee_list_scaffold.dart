import 'package:flutter/material.dart';

import '../state/employee_list_controller.dart';
import '../state/employee_view_state.dart';
import '../theme/employee_theme.dart';
import 'employee_states.dart';

/// The page every employee list screen is built from.
///
/// Owns the parts that must behave identically everywhere and are easy to get
/// subtly wrong per-screen: the scroll listener that triggers the next page,
/// the shimmer-vs-content decision, pull-to-refresh, and the refresh hairline
/// that keeps a silent reload from blanking the list.
///
/// A screen supplies its rows, its filters and its empty state; it never
/// touches paging.
class EmployeeListScaffold<T> extends StatefulWidget {
  const EmployeeListScaffold({
    super.key,
    required this.title,
    required this.controller,
    required this.itemBuilder,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
    this.subtitle,
    this.header,
    this.filters,
    this.actions,
    this.floatingActionButton,
    this.scopeNotice,
    this.exhaustedLabel = "That's everything",
  });

  final String title;

  /// A count or a scope line under the title. Rebuilt with the controller, so
  /// it can read `total`.
  final String Function()? subtitle;

  final EmployeeListController<T> controller;
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// Pinned above the list and outside the scroll view — filters must stay
  /// reachable while a long list is scrolled.
  final Widget? filters;

  /// Scrolls **with** the list, above the first row. For a stats strip that is
  /// worth reading once, not keeping on screen.
  final Widget? header;

  final List<Widget>? actions;
  final Widget? floatingActionButton;

  /// The complex-scope note. Null on the screens where it would be noise.
  final String? scopeNotice;

  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  final String exhaustedLabel;

  @override
  State<EmployeeListScaffold<T>> createState() =>
      _EmployeeListScaffoldState<T>();
}

class _EmployeeListScaffoldState<T> extends State<EmployeeListScaffold<T>> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Fetches the next page a screen-and-a-bit before the bottom, so the rows
  /// are usually there by the time the user reaches them.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final remaining = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 480) widget.controller.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EmployeeTokens.canvas,
      floatingActionButton: widget.floatingActionButton,
      appBar: AppBar(
        backgroundColor: EmployeeTokens.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        // Two stacked lines in a toolbar whose height is fixed at 56dp: past
        // roughly 1.3× the text overruns it. Clamping here keeps the bar
        // readable at large accessibility sizes without clipping — the page
        // body below scales without limit.
        title: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              final subtitle = widget.subtitle?.call();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if ((subtitle ?? '').isNotEmpty)
                    Text(
                      subtitle!,
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
          ...?widget.actions,
          AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) => IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: widget.controller.refreshing
                  ? null
                  : widget.controller.refresh,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) =>
                EmployeeRefreshLine(visible: widget.controller.refreshing),
          ),
        ),
      ),
      body: Column(
        children: [
          if (widget.filters != null)
            Container(
              width: double.infinity,
              color: EmployeeTokens.surface,
              padding: const EdgeInsets.fromLTRB(
                EmployeeTokens.space4,
                EmployeeTokens.space3,
                EmployeeTokens.space4,
                EmployeeTokens.space3,
              ),
              child: widget.filters,
            ),
          Expanded(
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) => RefreshIndicator(
                color: EmployeeTokens.brand,
                onRefresh: widget.controller.refresh,
                child: _body(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    final controller = widget.controller;

    if (controller.isInitialLoad) {
      return ListView(
        padding: const EdgeInsets.all(EmployeeTokens.space4),
        children: const [EmployeeListShimmer()],
      );
    }

    // A failure with rows already on screen is reported by the caller's
    // snackbar, not by replacing the list — only a first load that came back
    // with nothing gets the error page.
    if (controller.state.isFailed && controller.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: EmployeeTokens.space8),
          EmployeeErrorView(
            message: controller.error ?? 'That did not load.',
            onRetry: controller.reload,
          ),
        ],
      );
    }

    final items = controller.items;

    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        EmployeeTokens.space4,
        EmployeeTokens.space4,
        EmployeeTokens.space4,
        EmployeeTokens.space6,
      ),
      // Header + rows + footer, with the empty state standing in for the rows.
      itemCount: _leadingCount + (items.isEmpty ? 1 : items.length) + 1,
      itemBuilder: (context, index) {
        final leading = _leading(index);
        if (leading != null) return leading;

        final offset = index - _leadingCount;

        if (items.isEmpty) {
          if (offset > 0) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: EmployeeTokens.space6),
            child: EmployeeEmptyView(
              icon: widget.emptyIcon,
              title: widget.emptyTitle,
              message: widget.emptyMessage,
            ),
          );
        }

        if (offset >= items.length) {
          return EmployeeListFooter(
            loading: controller.loadingMore,
            hasMore: controller.hasMore,
            isEmpty: items.isEmpty,
            exhaustedLabel: widget.exhaustedLabel,
          );
        }

        return widget.itemBuilder(context, items[offset]);
      },
    );
  }

  int get _leadingCount =>
      (widget.scopeNotice == null ? 0 : 1) + (widget.header == null ? 0 : 1);

  /// The scope notice and the header occupy the first one or two slots.
  Widget? _leading(int index) {
    var cursor = index;

    if (widget.scopeNotice != null) {
      if (cursor == 0) {
        return Padding(
          padding: const EdgeInsets.only(bottom: EmployeeTokens.space4),
          child: EmployeeScopeNotice(message: widget.scopeNotice),
        );
      }
      cursor -= 1;
    }

    if (widget.header != null && cursor == 0) {
      return Padding(
        padding: const EdgeInsets.only(bottom: EmployeeTokens.space4),
        child: widget.header,
      );
    }

    return null;
  }
}
