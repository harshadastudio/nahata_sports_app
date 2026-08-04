import 'package:flutter/material.dart';

import '../../domain/entities/report.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'admin_states.dart';
import 'glass_card.dart';

/// How a report figure reads.
String formatFigure(ReportFigure figure) {
  final text = (figure.text ?? '').trim();
  if (figure.value == null) {
    return text.isEmpty ? AdminFormat.dash : text;
  }

  final value = figure.value!;
  switch (figure.format) {
    case ReportFormat.currency:
      return AdminFormat.currency(value);
    case ReportFormat.percent:
      return '${_plain(value)}%';
    case ReportFormat.minutes:
      return _duration(value);
    case ReportFormat.count:
      return value is int || value == value.roundToDouble()
          ? AdminFormat.number(value.round())
          : _plain(value);
    case ReportFormat.text:
      return _plain(value);
  }
}

/// `10` rather than `10.0`; two decimals only when they carry information.
String _plain(num value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(2);
}

/// The API reports these as hours in some places and minutes in others, and
/// says which in neither. Treated as hours, which is what "Idle hours" and
/// "Maintenance time" imply, and labelled so a misreading is visible.
String _duration(num value) {
  if (value == value.roundToDouble()) return '${value.round()} hrs';
  return '${value.toStringAsFixed(1)} hrs';
}

/// One analytics card.
class AnalyticsCard extends StatelessWidget {
  const AnalyticsCard({
    super.key,
    required this.figure,
    required this.icon,
    required this.gradient,
    this.loading = false,
    this.caption,
  });

  final ReportFigure figure;
  final IconData icon;
  final List<Color> gradient;
  final bool loading;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    if (loading) return const StatCardShimmer();

    final value = formatFigure(figure);
    final missing = value == AdminFormat.dash;

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(height: AdminTokens.space4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: missing ? tokens.textMuted : tokens.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            figure.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.textMuted, fontSize: 12),
          ),
          if (missing || caption != null) ...[
            const SizedBox(height: 2),
            Text(
              // An em dash means the endpoint did not send this figure, which
              // is a different claim from "zero".
              missing ? 'Not reported' : caption!,
              style: TextStyle(color: tokens.textMuted, fontSize: 10.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// A responsive grid of analytics cards.
class ReportFigureGrid extends StatelessWidget {
  const ReportFigureGrid({
    super.key,
    required this.figures,
    required this.loading,
    this.icons = const {},
    this.palette = const [],
  });

  final List<ReportFigure> figures;
  final bool loading;
  final Map<String, IconData> icons;
  final List<List<Color>> palette;

  static const List<List<Color>> defaultPalette = [
    [Color(0xFF1A237E), Color(0xFF3F51B5)],
    [Color(0xFF10B981), Color(0xFF34D399)],
    [Color(0xFF0EA5E9), Color(0xFF67E8F9)],
    [Color(0xFF3949AB), Color(0xFF7986CB)],
    [Color(0xFFF59E0B), Color(0xFFFCD34D)],
    [Color(0xFFEF4444), Color(0xFFFCA5A5)],
    [Color(0xFF16A34A), Color(0xFF86EFAC)],
    [Color(0xFFEC4899), Color(0xFFF9A8D4)],
  ];

  @override
  Widget build(BuildContext context) {
    if (figures.isEmpty && !loading) return const SizedBox.shrink();

    final colours = palette.isEmpty ? defaultPalette : palette;
    final shown = loading && figures.isEmpty
        ? [
            for (var i = 0; i < 4; i++)
              ReportFigure(key: 'placeholder$i', label: ' '),
          ]
        : figures;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1300
            ? 4
            : (constraints.maxWidth >= 900
                  ? 3
                  : (constraints.maxWidth >= 560 ? 2 : 2));
        const gap = AdminTokens.space4;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var index = 0; index < shown.length; index++)
              SizedBox(
                width: width,
                child: AnalyticsCard(
                  figure: shown[index],
                  loading: loading,
                  icon: icons[shown[index].key] ?? _iconFor(shown[index]),
                  gradient: colours[index % colours.length],
                ),
              ),
          ],
        );
      },
    );
  }

  static IconData _iconFor(ReportFigure figure) {
    switch (figure.format) {
      case ReportFormat.currency:
        return Icons.account_balance_wallet_rounded;
      case ReportFormat.percent:
        return Icons.percent_rounded;
      case ReportFormat.minutes:
        return Icons.schedule_rounded;
      case ReportFormat.count:
      case ReportFormat.text:
        return Icons.insights_rounded;
    }
  }
}

/// A card that owns one slice's loading, empty, error and content states.
class ReportSectionCard extends StatelessWidget {
  const ReportSectionCard({
    super.key,
    required this.title,
    required this.state,
    required this.error,
    required this.onRetry,
    required this.child,
    this.subtitle,
    this.isEmpty = false,
    this.emptyMessage,
    this.trailing,
    this.height,
  });

  final String title;
  final String? subtitle;
  final ViewState state;
  final String? error;
  final VoidCallback onRetry;
  final Widget child;
  final bool isEmpty;
  final String? emptyMessage;
  final Widget? trailing;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    Widget body;
    if (state.isLoading || state.isIdle) {
      body = const ShimmerBox(height: 180);
    } else if (state.isFailed) {
      body = ErrorStateView(
        compact: true,
        title: 'Could not load $title',
        message: error ?? 'Please try again.',
        onRetry: onRetry,
      );
    } else if (isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: AdminTokens.space6),
        child: Center(
          child: Text(
            // "No data in this window" and "the endpoint sent nothing we could
            // read" are different claims; this says only what is known.
            emptyMessage ?? 'Nothing was reported for this date range.',
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
          ),
        ),
      );
    } else {
      body = child;
    }

    return SolidCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AdminTokens.space4),
          if (height != null) SizedBox(height: height, child: body) else body,
        ],
      ),
    );
  }
}

/// The From / To picker, the presets, and the Refresh and Export buttons.
class ReportRangeBar extends StatelessWidget {
  const ReportRangeBar({
    super.key,
    required this.range,
    required this.preset,
    required this.busy,
    required this.onPreset,
    required this.onPickRange,
    required this.onRefresh,
    required this.onExport,
  });

  final DateRange range;
  final DateRangePreset? preset;
  final bool busy;
  final ValueChanged<DateRangePreset> onPreset;
  final VoidCallback onPickRange;
  final VoidCallback onRefresh;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < AdminTokens.tabletMax;

    final window = InkWell(
      onTap: onPickRange,
      borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AdminTokens.space4,
          vertical: AdminTokens.space3,
        ),
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 17,
              color: tokens.textMuted,
            ),
            const SizedBox(width: AdminTokens.space3),
            Flexible(
              child: Text(
                '${AdminFormat.date(range.from)} → '
                '${AdminFormat.date(range.to)}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AdminTokens.space2),
            Icon(Icons.expand_more_rounded, size: 18, color: tokens.textMuted),
          ],
        ),
      ),
    );

    final presets = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in DateRangePreset.values)
            Padding(
              padding: const EdgeInsets.only(right: AdminTokens.space2),
              child: _PresetChip(
                label: option.label,
                selected: preset == option,
                onTap: () => onPreset(option),
              ),
            ),
        ],
      ),
    );

    final refresh = OutlinedButton.icon(
      onPressed: busy ? null : onRefresh,
      icon: busy
          ? const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_rounded, size: 18),
      label: const Text('Refresh'),
    );

    final export = OutlinedButton.icon(
      onPressed: onExport,
      icon: const Icon(Icons.download_rounded, size: 18),
      label: const Text('Export'),
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          window,
          const SizedBox(height: AdminTokens.space3),
          presets,
          const SizedBox(height: AdminTokens.space3),
          Row(
            children: [
              Expanded(child: refresh),
              const SizedBox(width: AdminTokens.space3),
              Expanded(child: export),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        window,
        const SizedBox(width: AdminTokens.space3),
        Expanded(child: presets),
        const SizedBox(width: AdminTokens.space3),
        refresh,
        const SizedBox(width: AdminTokens.space3),
        export,
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AdminTokens.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AdminTokens.space3,
          vertical: AdminTokens.space2 + 1,
        ),
        decoration: BoxDecoration(
          color: selected ? tokens.accentSoft : tokens.surface,
          borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
          border: Border.all(
            color: selected ? tokens.accent : tokens.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? tokens.accent : tokens.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// The dropdowns a `/filter-options` payload fills, plus the search box.
class ReportFilterBar extends StatelessWidget {
  const ReportFilterBar({
    super.key,
    required this.options,
    required this.optionsState,
    required this.filters,
    required this.searchController,
    required this.searchHint,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onFilterChanged,
    required this.onClearFilters,
    required this.onReloadOptions,
  });

  final ReportFilterOptions? options;
  final ViewState optionsState;
  final ReportFilters filters;
  final TextEditingController searchController;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final void Function(String key, String? value) onFilterChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onReloadOptions;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < AdminTokens.tabletMax;
    final groups = options?.groups ?? const <String, List<FilterOption>>{};

    final search = SizedBox(
      width: narrow ? double.infinity : 300,
      child: TextField(
        controller: searchController,
        onChanged: onSearchChanged,
        style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
        decoration: InputDecoration(
          hintText: searchHint,
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: tokens.textMuted,
          ),
          suffixIcon: searchController.text.isEmpty
              ? null
              : IconButton(
                  onPressed: onClearSearch,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: tokens.textMuted,
                  tooltip: 'Clear',
                ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        search,
        if (optionsState.isFailed) ...[
          const SizedBox(height: AdminTokens.space3),
          Row(
            children: [
              Icon(
                Icons.filter_alt_off_outlined,
                size: 15,
                color: tokens.textMuted,
              ),
              const SizedBox(width: AdminTokens.space2),
              Expanded(
                child: Text(
                  // The table still works; only the dropdowns are missing.
                  'The filter options could not be loaded, so only search is '
                  'available.',
                  style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                ),
              ),
              TextButton(onPressed: onReloadOptions, child: const Text('Retry')),
            ],
          ),
        ],
        if (groups.isNotEmpty) ...[
          const SizedBox(height: AdminTokens.space3),
          Wrap(
            spacing: AdminTokens.space3,
            runSpacing: AdminTokens.space3,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final entry in groups.entries)
                SizedBox(
                  width: narrow ? double.infinity : 220,
                  child: _FilterDropdown(
                    // The key is the server's own, so a group this console has
                    // never heard of still gets a working dropdown.
                    label: _humanise(entry.key),
                    value: filters[entry.key],
                    options: entry.value,
                    onChanged: (value) => onFilterChanged(entry.key, value),
                  ),
                ),
              if (!filters.isEmpty)
                TextButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                  label: const Text('Clear filters'),
                  style: TextButton.styleFrom(
                    foregroundColor: tokens.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  static String _humanise(String key) {
    final spaced = key
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match[1]} ${match[2]}',
        )
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .trim();
    if (spaced.isEmpty) return key;
    return spaced[0].toUpperCase() + spaced.substring(1).toLowerCase();
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<FilterOption> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    // A value the option list does not contain would assert in the dropdown, so
    // it is dropped back to "All" rather than crashing the bar.
    final selected = options.any((option) => option.id == value) ? value : null;

    return DropdownButtonFormField<String?>(
      initialValue: selected,
      isExpanded: true,
      icon: Icon(Icons.expand_more_rounded, size: 18, color: tokens.textMuted),
      style: TextStyle(fontSize: 13, color: tokens.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AdminTokens.space3,
          vertical: AdminTokens.space3,
        ),
      ),
      items: [
        const DropdownMenuItem<String?>(child: Text('All')),
        for (final option in options)
          DropdownMenuItem<String?>(
            value: option.id,
            child: Text(option.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}
