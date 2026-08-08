import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/contact_inquiry.dart';
import '../state/contact_enquiries_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/admin_states.dart';
import '../widgets/contact_enquiries_table.dart';
import '../widgets/contact_inquiry_detail_panel.dart';
import '../widgets/contact_stat_cards.dart';
import '../widgets/glass_card.dart';
import '../widgets/pagination_bar.dart';

/// Contact Enquiries — the "Contact Us" queue from `GET /contact-us/admin`.
///
/// One screen for both administrative roles: the endpoint is shared and the
/// backend scopes the rows from the JWT, so a COMPLEX_ADMIN sees its own venue's
/// enquiries without the console asking for a complex.
///
/// Read-only. The confirmed API has one route, so there is no create, no status
/// change and no delete — and no button implying otherwise.
class ContactEnquiriesPage extends StatefulWidget {
  const ContactEnquiriesPage({super.key});

  @override
  State<ContactEnquiriesPage> createState() => _ContactEnquiriesPageState();
}

class _ContactEnquiriesPageState extends State<ContactEnquiriesPage> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    AdminLog.life('ContactEnquiriesPage mounted');
    _search = TextEditingController(
      text: context.read<ContactEnquiriesController>().search,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<ContactEnquiriesController>();
      if (controller.state.isIdle) controller.load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    AdminLog.life('ContactEnquiriesPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ContactEnquiriesController>();
    final tokens = AdminTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < AdminTokens.mobileMax;
    final isDesktop = width >= AdminTokens.tabletMax;

    // Deferred past this frame: writing to the controller mid-build would mark
    // the TextField dirty while its ancestor is still building.
    if (_search.text != controller.search) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _search.text == controller.search) return;
        _search.value = TextEditingValue(
          text: controller.search,
          selection: TextSelection.collapsed(offset: controller.search.length),
        );
      });
    }

    final selected = controller.selected;

    final list = ColoredBox(
      color: tokens.canvas,
      child: Padding(
        padding: EdgeInsets.all(
          isMobile ? AdminTokens.space4 : AdminTokens.space6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ContactStatCards(
              counts: controller.counts,
              state: controller.state,
              activeFilter: controller.statusFilter,
              onFilter: controller.toggleStatusFilter,
              onClearFilter: () => controller.setStatusFilter(null),
            ),
            const SizedBox(height: AdminTokens.space5),
            _Toolbar(controller: controller, searchController: _search),
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
                          onAction: (action, enquiry) =>
                              _handleAction(context, controller, action, enquiry),
                        ),
                      ),
                      if (controller.page.items.isNotEmpty ||
                          controller.page.page > 1)
                        PaginationBar(
                          page: controller.page,
                          limit: controller.limit,
                          busy: controller.state.isLoading,
                          onPage: controller.goToPage,
                          onLimit: controller.setLimit,
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

    if (!isDesktop || selected == null) return list;

    return Row(
      children: [
        Expanded(child: list),
        AnimatedContainer(
          duration: AdminTokens.normal,
          curve: AdminTokens.curve,
          width: AdminTokens.detailDrawerWidth,
          decoration: BoxDecoration(
            color: tokens.canvas,
            border: Border(left: BorderSide(color: tokens.border)),
          ),
          child: ContactInquiryDetailPanel(
            enquiry: selected,
            onClose: controller.clearSelection,
            onEmail: () => _email(context, selected),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _handleAction(
    BuildContext context,
    ContactEnquiriesController controller,
    ContactEnquiryAction action,
    ContactInquiry enquiry,
  ) async {
    switch (action) {
      case ContactEnquiryAction.view:
        controller.select(enquiry);
        if (MediaQuery.sizeOf(context).width < AdminTokens.tabletMax) {
          await _showDetailSheet(context, controller);
        }
      case ContactEnquiryAction.email:
        await _email(context, enquiry);
    }
  }

  /// Opens the device's mail app with the reference number already in the
  /// subject line. The console cannot send mail itself — there is no reply
  /// route — so this hands off rather than pretending.
  Future<void> _email(BuildContext context, ContactInquiry enquiry) async {
    final address = (enquiry.email ?? '').trim();
    if (address.isEmpty) return;

    final reference = (enquiry.referenceNumber ?? '').trim();
    final subject = [
      'Re: ${enquiry.subjectLabel}',
      if (reference.isNotEmpty) '[$reference]',
    ].join(' ');

    final uri = Uri(
      scheme: 'mailto',
      path: address,
      query: 'subject=${Uri.encodeComponent(subject)}',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !context.mounted) return;
      AdminFeedback.info(context, 'No email app is available on this device.');
    } catch (error) {
      AdminLog.failure('Could not open $address', error: error);
      if (!context.mounted) return;
      AdminFeedback.info(context, 'No email app is available on this device.');
    }
  }

  Future<void> _showDetailSheet(
    BuildContext context,
    ContactEnquiriesController controller,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminTheme.of(context).canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AdminTokens.radiusXl),
        ),
      ),
      builder: (sheetContext) {
        return ChangeNotifierProvider<ContactEnquiriesController>.value(
          value: controller,
          child: Consumer<ContactEnquiriesController>(
            builder: (context, live, _) {
              final enquiry = live.selected;
              if (enquiry == null) return const SizedBox.shrink();

              // top: false — the sheet is bottom-anchored, so only the gesture
              // bar has to be kept clear of the panel's buttons.
              return SafeArea(
                top: false,
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.9,
                  child: ContactInquiryDetailPanel(
                    enquiry: enquiry,
                    onClose: () => Navigator.of(sheetContext).pop(),
                    onEmail: () => _email(sheetContext, enquiry),
                  ),
                ),
              );
            },
          ),
        );
      },
    ).whenComplete(controller.clearSelection);
  }
}

// -----------------------------------------------------------------------------
// Toolbar
// -----------------------------------------------------------------------------

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller, required this.searchController});

  final ContactEnquiriesController controller;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < AdminTokens.tabletMax;

    final search = SizedBox(
      width: narrow ? double.infinity : 320,
      child: TextField(
        controller: searchController,
        onChanged: controller.onSearchChanged,
        style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
        decoration: InputDecoration(
          // Says plainly what it does. The endpoint has no confirmed search
          // parameter, so this narrows the page on screen — promising more
          // would be a search box that quietly misses most of the dataset.
          hintText: 'Filter this page',
          prefixIcon: Icon(
            Icons.filter_alt_outlined,
            size: 18,
            color: tokens.textMuted,
          ),
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

    final filterChip = controller.statusFilter == null
        ? null
        : InputChip(
            label: Text('${controller.statusFilter!.label} only'),
            onDeleted: () => controller.setStatusFilter(null),
            deleteIcon: const Icon(Icons.close_rounded, size: 15),
            labelStyle: TextStyle(fontSize: 12, color: tokens.accent),
            backgroundColor: tokens.accentSoft,
            side: BorderSide(color: tokens.accent.withValues(alpha: 0.3)),
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

    final scopeNote = controller.filterIsPageScoped
        ? _ScopeNote(
            shown: controller.enquiries.length,
            loaded: controller.loadedCount,
            total: controller.page.total,
          )
        : null;

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          if (filterChip != null) ...[
            const SizedBox(height: AdminTokens.space3),
            Align(alignment: Alignment.centerLeft, child: filterChip),
          ],
          if (scopeNote != null) ...[
            const SizedBox(height: AdminTokens.space2),
            scopeNote,
          ],
          const SizedBox(height: AdminTokens.space3),
          refresh,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            search,
            if (filterChip != null) ...[
              const SizedBox(width: AdminTokens.space3),
              filterChip,
            ],
            const Spacer(),
            refresh,
          ],
        ),
        if (scopeNote != null) ...[
          const SizedBox(height: AdminTokens.space2),
          Align(alignment: Alignment.centerLeft, child: scopeNote),
        ],
      ],
    );
  }
}

/// Says exactly how much of the dataset the active filter can see.
///
/// Without this the module would look like it filtered everything, when it can
/// only reach the page the server sent.
class _ScopeNote extends StatelessWidget {
  const _ScopeNote({
    required this.shown,
    required this.loaded,
    required this.total,
  });

  final int shown;
  final int loaded;
  final int total;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.info_outline_rounded, size: 14, color: tokens.textMuted),
        const SizedBox(width: AdminTokens.space2),
        Flexible(
          child: Text(
            'Showing $shown of the $loaded on this page — '
            'filtering applies to this page only'
            '${total > loaded ? ' ($total in total)' : ''}.',
            style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
          ),
        ),
      ],
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
    required this.onAction,
  });

  final ContactEnquiriesController controller;
  final bool isMobile;
  final void Function(ContactEnquiryAction action, ContactInquiry enquiry)
  onAction;

  @override
  Widget build(BuildContext context) {
    if (controller.isFirstLoad) {
      return SingleChildScrollView(
        child: TableShimmer(rows: 7, dense: isMobile),
      );
    }

    if (controller.state.isFailed && controller.page.items.isEmpty) {
      return ErrorStateView(
        title: 'Could not load contact enquiries',
        message:
            controller.error ??
            'The server did not return a list. Check your connection and '
                'try again.',
        onRetry: controller.refresh,
      );
    }

    final enquiries = controller.enquiries;

    if (enquiries.isEmpty) {
      return controller.hasFilters
          ? EmptyStateView(
              icon: Icons.filter_alt_off_outlined,
              title: 'Nothing on this page matches',
              message:
                  'The filter only looks at the page you are on. Clear it, or '
                  'try another page.',
              actionLabel: 'Clear filters',
              onAction: controller.clearFilters,
            )
          : EmptyStateView(
              icon: Icons.mark_email_read_outlined,
              title: 'No contact enquiries yet',
              message:
                  'Messages sent through the website\'s contact form land '
                  'here.',
              actionLabel: 'Refresh',
              onAction: controller.refresh,
            );
    }

    if (isMobile) {
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView.builder(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: enquiries.length,
          itemBuilder: (context, index) => ContactEnquiryCard(
            key: ValueKey<String>(enquiries[index].id),
            enquiry: enquiries[index],
            onAction: onAction,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A failed page change would otherwise leave the previous page on
        // screen with nothing to say it did not move.
        if (controller.state.isFailed)
          _InlineError(
            message: controller.error ?? 'Could not refresh this list.',
            onRetry: controller.refresh,
          ),
        Expanded(
          child: SingleChildScrollView(
            child: ContactEnquiriesTable(
              enquiries: enquiries,
              onAction: onAction,
              selectedId: controller.selected?.id,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space5,
        vertical: AdminTokens.space3,
      ),
      decoration: BoxDecoration(
        color: tokens.danger.withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 17, color: tokens.danger),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: tokens.danger, fontSize: 12.5),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}