import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/employee_formats.dart';
import '../theme/employee_theme.dart';

/// The form and dialog vocabulary the employee module writes with.
///
/// Six of the employee screens are CRUD over a small record (sport, court,
/// slot, batch, fee, user). Building each one's form by hand would mean six
/// slightly different date pickers and six slightly different validation
/// messages, so the pieces live here once.

// ─────────────────────────────────────────────────────────────────────────────
// Bottom sheet scaffolding
// ─────────────────────────────────────────────────────────────────────────────

/// Opens a form as a draggable bottom sheet.
///
/// A sheet rather than a full page because these forms are short and the list
/// behind them is the context — the website uses a slide-over panel for exactly
/// the same reason. Returns whatever the sheet pops with, so the caller can
/// tell "saved" from "dismissed".
Future<T?> showEmployeeSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required Widget Function(BuildContext) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // The keyboard has to be able to push the sheet up without the header
    // scrolling off, hence the explicit height cap rather than `expand: true`.
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, controller) => EmployeeSheetShell(
        title: title,
        subtitle: subtitle,
        scrollController: controller,
        child: builder(context),
      ),
    ),
  );
}

/// The chrome every sheet shares: grab handle, title, scrollable body.
class EmployeeSheetShell extends StatelessWidget {
  const EmployeeSheetShell({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.scrollController,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: EmployeeTokens.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(EmployeeTokens.radiusLg),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: EmployeeTokens.space2 + 2),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: EmployeeTokens.border,
              borderRadius: BorderRadius.circular(EmployeeTokens.radiusPill),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              EmployeeTokens.space5,
              EmployeeTokens.space4,
              EmployeeTokens.space4,
              EmployeeTokens.space3,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: EmployeeTokens.textDark,
                        ),
                      ),
                      if ((subtitle ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: EmployeeTokens.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: EmployeeTokens.textMuted,
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: EmployeeTokens.border),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                EmployeeTokens.space5,
                EmployeeTokens.space4,
                EmployeeTokens.space5,
                // Clears the keyboard when one is up, and the home indicator
                // when one is not.
                MediaQuery.of(context).viewInsets.bottom + EmployeeTokens.space6,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// The save / cancel pair every form sheet ends with.
class EmployeeSheetActions extends StatelessWidget {
  const EmployeeSheetActions({
    super.key,
    required this.onSave,
    this.saving = false,
    this.saveLabel = 'Save',
    this.destructive = false,
  });

  final VoidCallback? onSave;
  final bool saving;
  final String saveLabel;

  /// Colours the primary button red — for a delete confirmation rather than a
  /// save.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tone = destructive ? EmployeeTokens.danger : EmployeeTokens.brand;

    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: saving ? null : onSave,
            style: FilledButton.styleFrom(
              backgroundColor: tone,
              padding: const EdgeInsets.symmetric(
                vertical: EmployeeTokens.space4,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
              ),
            ),
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    saveLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: EmployeeTokens.space3),
        OutlinedButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            foregroundColor: EmployeeTokens.textBody,
            side: const BorderSide(color: EmployeeTokens.border),
            padding: const EdgeInsets.symmetric(
              horizontal: EmployeeTokens.space5,
              vertical: EmployeeTokens.space4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
            ),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// The inline error a form shows when the server refuses a save.
///
/// Kept on the form rather than in a snackbar: the message usually names a
/// field ("A court with this name already exists"), and a snackbar would be
/// gone before the user finished reading the field it refers to.
class EmployeeFormError extends StatelessWidget {
  const EmployeeFormError({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message?.trim();
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space4),
      padding: const EdgeInsets.all(EmployeeTokens.space3),
      decoration: BoxDecoration(
        color: EmployeeTokens.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
        border: Border.all(
          color: EmployeeTokens.danger.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 17,
            color: EmployeeTokens.danger,
          ),
          const SizedBox(width: EmployeeTokens.space2),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: EmployeeTokens.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fields
// ─────────────────────────────────────────────────────────────────────────────

/// A labelled wrapper, so every field in every form sits the same distance from
/// its label.
class EmployeeField extends StatelessWidget {
  const EmployeeField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
    this.hint,
  });

  final String label;
  final Widget child;
  final bool required;

  /// A note under the field — used where the API's behaviour is not obvious
  /// from the field itself.
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EmployeeTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10.5,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w700,
                  color: EmployeeTokens.textMuted,
                ),
              ),
              if (required)
                const Text(
                  ' *',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: EmployeeTokens.danger,
                  ),
                ),
            ],
          ),
          const SizedBox(height: EmployeeTokens.space2),
          child,
          if ((hint ?? '').isNotEmpty) ...[
            const SizedBox(height: EmployeeTokens.space1 + 2),
            Text(
              hint!,
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
                color: EmployeeTokens.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The one input decoration this module uses.
InputDecoration employeeInputDecoration({
  String? hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? prefixText,
}) {
  OutlineInputBorder border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    prefixText: prefixText,
    isDense: true,
    filled: true,
    fillColor: EmployeeTokens.canvas,
    hintStyle: const TextStyle(
      fontSize: 13.5,
      color: EmployeeTokens.textMuted,
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: EmployeeTokens.space3 + 2,
      vertical: EmployeeTokens.space3 + 2,
    ),
    border: border(EmployeeTokens.border),
    enabledBorder: border(EmployeeTokens.border),
    focusedBorder: border(EmployeeTokens.brand, 1.4),
    errorBorder: border(EmployeeTokens.danger),
    focusedErrorBorder: border(EmployeeTokens.danger, 1.4),
  );
}

/// A plain text input.
class EmployeeTextField extends StatelessWidget {
  const EmployeeTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.keyboardType,
    this.maxLines = 1,
    this.prefixIcon,
    this.prefixText,
    this.textCapitalization = TextCapitalization.sentences,
    this.enabled = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? hintText;
  final TextInputType? keyboardType;
  final int maxLines;
  final IconData? prefixIcon;
  final String? prefixText;
  final TextCapitalization textCapitalization;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        fontSize: 14,
        color: EmployeeTokens.textDark,
      ),
      decoration: employeeInputDecoration(
        hintText: hintText,
        prefixText: prefixText,
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 18, color: EmployeeTokens.textMuted),
      ),
    );
  }
}

/// A number input. Separated from [EmployeeTextField] because the keyboard,
/// the input filter and the ₹ prefix all have to agree — every money field in
/// this module goes through here.
class EmployeeNumberField extends StatelessWidget {
  const EmployeeNumberField({
    super.key,
    required this.controller,
    this.hintText,
    this.isCurrency = false,
    this.allowDecimal = true,
  });

  final TextEditingController controller;
  final String? hintText;
  final bool isCurrency;
  final bool allowDecimal;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          allowDecimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
        ),
      ],
      style: const TextStyle(
        fontSize: 14,
        color: EmployeeTokens.textDark,
      ),
      decoration: employeeInputDecoration(
        hintText: hintText,
        prefixText: isCurrency ? '₹ ' : null,
      ),
    );
  }
}

/// A dropdown over a fixed vocabulary.
class EmployeeDropdown<T> extends StatelessWidget {
  const EmployeeDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.placeholder = 'Select',
    this.subtitleOf,
  });

  final T? value;
  final List<T> items;
  final String Function(T) labelOf;

  /// A second line on the option — a batch's fee, a court's sport.
  final String? Function(T)? subtitleOf;

  final ValueChanged<T?> onChanged;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    // A value that is no longer in the list (the record it pointed at was
    // deleted, or the list has not loaded yet) would make DropdownButton assert,
    // so it is dropped to null instead.
    final safeValue = items.contains(value) ? value : null;

    return DropdownButtonFormField<T>(
      initialValue: safeValue,
      isExpanded: true,
      // Null lets a menu row size to its own content. The default
      // (`kMinInteractiveDimension`) pins every row to exactly 48, which a
      // two-line option outgrows once the device's font scale is raised.
      // `DropdownMenuItem` applies its own `minHeight: 48`, so 48 remains the
      // floor and the menu looks unchanged at normal text settings.
      itemHeight: null,
      // The closed button gets a **one-line** rendering of the same option.
      //
      // `InputDecorator` sizes its content to a single line of `style`, and
      // hands the child a tight height — 24px at normal text scale. A
      // label-plus-subtitle Column needs ~25px, so the second line has in fact
      // been clipped here since day one (1px at 1.0×, ~6px at 1.6×, which is
      // the overflow reported from a handset).
      //
      // The subtitle exists to help *choose* an option, and the menu below
      // still shows it in full. Once chosen, the label identifies it.
      selectedItemBuilder: (context) => items
          .map(
            (item) => Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                labelOf(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: EmployeeTokens.textDark,
                ),
              ),
            ),
          )
          .toList(),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: EmployeeTokens.textMuted,
      ),
      style: const TextStyle(fontSize: 14, color: EmployeeTokens.textDark),
      decoration: employeeInputDecoration(),
      hint: Text(
        placeholder,
        style: const TextStyle(
          fontSize: 13.5,
          color: EmployeeTokens.textMuted,
        ),
      ),
      items: items.map((item) {
        final subtitle = subtitleOf?.call(item);
        return DropdownMenuItem<T>(
          value: item,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                labelOf(item),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
              if ((subtitle ?? '').isNotEmpty)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: EmployeeTokens.textMuted,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}

/// A date field that opens the platform picker.
class EmployeeDateField extends StatelessWidget {
  const EmployeeDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Select a date',
    this.firstDate,
    this.lastDate,
    this.clearable = true,
  });

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String placeholder;
  final DateTime? firstDate;
  final DateTime? lastDate;

  /// Whether the field offers a clear button. Off for a required date.
  final bool clearable;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: firstDate ?? DateTime(now.year - 3),
          lastDate: lastDate ?? DateTime(now.year + 3),
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
      child: InputDecorator(
        decoration: employeeInputDecoration(
          prefixIcon: const Icon(
            Icons.calendar_today_rounded,
            size: 17,
            color: EmployeeTokens.textMuted,
          ),
          suffixIcon: clearable && value != null
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 17),
                  color: EmployeeTokens.textMuted,
                  onPressed: () => onChanged(null),
                  tooltip: 'Clear',
                )
              : null,
        ),
        child: Text(
          value == null ? placeholder : formatDay(value),
          style: TextStyle(
            fontSize: 14,
            color: value == null
                ? EmployeeTokens.textMuted
                : EmployeeTokens.textDark,
          ),
        ),
      ),
    );
  }
}

/// A time field that opens the platform picker and hands back `HH:mm`.
class EmployeeTimeField extends StatelessWidget {
  const EmployeeTimeField({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Select a time',
  });

  /// `HH:mm` or `HH:mm:ss` — whatever the API sent is accepted, and `HH:mm` is
  /// handed back.
  final String? value;

  final ValueChanged<String> onChanged;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _parse(value) ?? TimeOfDay.now(),
        );
        if (picked == null) return;
        final hour = picked.hour.toString().padLeft(2, '0');
        final minute = picked.minute.toString().padLeft(2, '0');
        onChanged('$hour:$minute');
      },
      borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
      child: InputDecorator(
        decoration: employeeInputDecoration(
          prefixIcon: const Icon(
            Icons.schedule_rounded,
            size: 17,
            color: EmployeeTokens.textMuted,
          ),
        ),
        child: Text(
          formatClock(value) ?? placeholder,
          style: TextStyle(
            fontSize: 14,
            color: (value ?? '').isEmpty
                ? EmployeeTokens.textMuted
                : EmployeeTokens.textDark,
          ),
        ),
      ),
    );
  }

  static TimeOfDay? _parse(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    final parts = text.split(':');
    final hour = int.tryParse(parts.first);
    if (hour == null) return null;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return TimeOfDay(hour: hour, minute: minute);
  }
}

/// A yes/no row.
class EmployeeSwitchField extends StatelessWidget {
  const EmployeeSwitchField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EmployeeTokens.space4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: EmployeeTokens.textDark,
                  ),
                ),
                if ((subtitle ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: EmployeeTokens.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: EmployeeTokens.brand,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filters
// ─────────────────────────────────────────────────────────────────────────────

/// A horizontally scrolling row of filter chips.
///
/// Tapping the selected chip clears the filter, so the row toggles rather than
/// trapping the user on a value with no way back to "all".
class EmployeeFilterChips<T> extends StatelessWidget {
  const EmployeeFilterChips({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.allLabel = 'All',
  });

  final List<T> values;
  final T? selected;
  final String Function(T) labelOf;

  /// Called with null when the "all" chip (or the selected chip) is tapped.
  final ValueChanged<T?> onChanged;

  final String allLabel;

  @override
  Widget build(BuildContext context) {
    // A scroll view rather than a fixed-height horizontal ListView: the chips
    // are text, so their height follows the user's font scale, and a hard
    // 36px box clips them the moment that scale goes past ~1.4.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip(
            label: allLabel,
            active: selected == null,
            onTap: () => onChanged(null),
          ),
          for (final value in values) ...[
            const SizedBox(width: EmployeeTokens.space2),
            _chip(
              label: labelOf(value),
              active: value == selected,
              onTap: () => onChanged(value == selected ? null : value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: active ? EmployeeTokens.brand : EmployeeTokens.surface,
      borderRadius: BorderRadius.circular(EmployeeTokens.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EmployeeTokens.radiusPill),
        child: Container(
          // A floor rather than a fixed height: keeps the chip exactly the
          // size it has always been at normal text settings, and lets it grow
          // instead of clipping when the system font is scaled up.
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(
            horizontal: EmployeeTokens.space4,
            vertical: EmployeeTokens.space2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(EmployeeTokens.radiusPill),
            border: Border.all(
              color: active ? EmployeeTokens.brand : EmployeeTokens.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : EmployeeTokens.textBody,
            ),
          ),
        ),
      ),
    );
  }
}

/// The search box that sits above a list.
class EmployeeSearchBar extends StatelessWidget {
  const EmployeeSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Search',
    this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14, color: EmployeeTokens.textDark),
      decoration: employeeInputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 19,
          color: EmployeeTokens.textMuted,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: EmployeeTokens.textMuted,
                onPressed: () {
                  controller.clear();
                  (onClear ?? () => onChanged(''))();
                },
                tooltip: 'Clear',
              ),
      ).copyWith(fillColor: EmployeeTokens.surface),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialogs and feedback
// ─────────────────────────────────────────────────────────────────────────────

/// A yes/no confirmation. Returns true only on an explicit confirm.
Future<bool> confirmEmployeeAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EmployeeTokens.radiusMd),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      content: Text(
        message,
        style: const TextStyle(fontSize: 13.5, height: 1.45),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: EmployeeTokens.textMuted,
          ),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor:
                destructive ? EmployeeTokens.danger : EmployeeTokens.brand,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  return result ?? false;
}

/// A one-line result message.
void showEmployeeToast(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  if (!context.mounted) return;

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13.5)),
        backgroundColor:
            isError ? EmployeeTokens.danger : EmployeeTokens.textDark,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(EmployeeTokens.space4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
        ),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
}
