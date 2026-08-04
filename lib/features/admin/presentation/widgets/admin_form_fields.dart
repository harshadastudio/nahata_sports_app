import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/admin_role.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';

/// The pieces every admin form dialog is built from.
///
/// Phases 3–8 each grew a private copy of these — the same header, footer,
/// section rule, label, text field and read-only box, redeclared six times.
/// This is that set, extracted once so the Courts module (and whatever comes
/// after it) shares one definition. The existing dialogs are deliberately left
/// alone: they are shipped and tested, and rewriting them would be churn
/// rather than improvement.

/// The label above every field, with the required marker.
class AdminFieldLabel extends StatelessWidget {
  const AdminFieldLabel(this.text, {super.key, this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return RichText(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: tokens.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        children: [
          if (required)
            TextSpan(
              text: ' *',
              style: TextStyle(color: tokens.danger, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class AdminTextField extends StatelessWidget {
  const AdminTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.required = false,
    this.enabled = true,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.obscureText = false,
    this.suffix,
    this.onChanged,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final bool required;
  final bool enabled;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminFieldLabel(label, required: required),
        const SizedBox(height: AdminTokens.space2),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          // An obscured field cannot be multiline.
          maxLines: obscureText ? 1 : maxLines,
          obscureText: obscureText,
          onChanged: onChanged,
          validator: validator,
          style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: tokens.textMuted),
            // A multiline box aligns its icon to the first line.
            prefixIconConstraints: maxLines > 1
                ? const BoxConstraints(minWidth: 44, minHeight: 44)
                : null,
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }
}

/// Free text with a set of known-good values offered as shortcuts.
///
/// Used where a column is constrained by the database but has no endpoint
/// listing its members: the values already in use are the only ones this app
/// can prove acceptable, so they lead — but anything can still be typed,
/// because the list being incomplete must not block a legitimate value.
class AdminSuggestionField extends StatelessWidget {
  const AdminSuggestionField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.suggestions,
    this.hint,
    this.required = false,
    this.enabled = true,
    this.note,
    this.rejectedValue,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final List<String> suggestions;
  final String? hint;
  final bool required;
  final bool enabled;
  final String? note;

  /// A value the server has already refused. Turns the note into a warning.
  final String? rejectedValue;

  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final refused = rejectedValue != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminFieldLabel(label, required: required),
        const SizedBox(height: AdminTokens.space2),
        TextFormField(
          controller: controller,
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          validator: validator,
          style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: tokens.textMuted),
            suffixIcon: suggestions.isEmpty
                ? null
                : PopupMenuButton<String>(
                    tooltip: 'Values already in use',
                    icon: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: tokens.textMuted,
                    ),
                    onSelected: (value) => controller.text = value,
                    itemBuilder: (context) => suggestions
                        .map(
                          (value) => PopupMenuItem<String>(
                            value: value,
                            height: 40,
                            child: Text(
                              value,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ),
        if (refused || note != null) ...[
          const SizedBox(height: 6),
          Text(
            refused
                ? 'The server refused "$rejectedValue". This column only '
                      'accepts a fixed set of values — pick one already in use.'
                : note!,
            style: TextStyle(
              color: refused ? tokens.warning : tokens.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

/// A dropdown over a fetched catalogue, with its own retry when it failed.
class AdminCatalogueDropdown<T> extends StatelessWidget {
  const AdminCatalogueDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.options,
    required this.value,
    required this.labelOf,
    required this.idOf,
    required this.state,
    required this.onReload,
    required this.enabled,
    required this.onChanged,
    this.required = false,
    this.error,
    this.note,
  });

  final String label;
  final IconData icon;
  final List<T> options;
  final T? value;
  final String Function(T value) labelOf;
  final int Function(T value) idOf;
  final ViewState state;
  final VoidCallback onReload;
  final bool enabled;
  final ValueChanged<T?> onChanged;
  final bool required;
  final String? error;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    // A selection that is no longer in the option list would assert inside
    // DropdownButtonFormField, so it is dropped rather than passed through.
    // `current` is promoted to T before idOf sees it; passing `value`
    // directly leaves it Object? at the call site.
    final T? current = value;
    final T? selected =
        (current != null &&
            options.any((option) => idOf(option) == idOf(current)))
        ? current
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            AdminFieldLabel(label, required: required),
            const Spacer(),
            if (state.isLoading)
              const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (state.isFailed)
              TextButton(
                onPressed: onReload,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Retry', style: TextStyle(fontSize: 11.5)),
              ),
          ],
        ),
        const SizedBox(height: AdminTokens.space2),
        DropdownButtonFormField<T>(
          initialValue: selected,
          isExpanded: true,
          onChanged: enabled && options.isNotEmpty ? onChanged : null,
          validator: (picked) {
            if (error != null) return error;
            if (required && picked == null) return '$label is required';
            return null;
          },
          dropdownColor: tokens.surface,
          borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          icon: Icon(
            Icons.expand_more_rounded,
            size: 18,
            color: tokens.textMuted,
          ),
          style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
          hint: Text(
            state.isLoading
                ? 'Loading…'
                : (options.isEmpty
                      ? 'Nothing available'
                      : 'Select ${label.toLowerCase()}'),
            style: TextStyle(fontSize: 13.5, color: tokens.textMuted),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: tokens.textMuted),
          ),
          items: options
              .map(
                (option) => DropdownMenuItem<T>(
                  value: option,
                  child: Text(
                    labelOf(option),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
              )
              .toList(),
        ),
        if (note != null) ...[
          const SizedBox(height: 6),
          Text(
            note!,
            style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
          ),
        ],
      ],
    );
  }
}

/// A dropdown over a fixed vocabulary.
class AdminVocabularyDropdown<T> extends StatelessWidget {
  const AdminVocabularyDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.required = false,
    this.enabled = true,
    this.error,
    this.emptyMessage,
  });

  final String label;
  final IconData icon;
  final T? value;
  final List<T> items;
  final String Function(T value) labelOf;
  final ValueChanged<T?> onChanged;
  final bool required;
  final bool enabled;
  final String? error;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminFieldLabel(label, required: required),
        const SizedBox(height: AdminTokens.space2),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          onChanged: enabled ? onChanged : null,
          validator: (selected) {
            if (error != null) return error;
            if (required && selected == null) {
              return emptyMessage ?? '$label is required';
            }
            return null;
          },
          dropdownColor: tokens.surface,
          borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          icon: Icon(
            Icons.expand_more_rounded,
            size: 18,
            color: tokens.textMuted,
          ),
          style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
          hint: Text(
            'Select ${label.toLowerCase()}',
            style: TextStyle(fontSize: 13.5, color: tokens.textMuted),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: tokens.textMuted),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    labelOf(item),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

/// Active / Inactive, the one dropdown every module has.
class AdminStatusDropdown extends StatelessWidget {
  const AdminStatusDropdown({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.error,
  });

  final AdminUserStatus? value;
  final bool enabled;
  final ValueChanged<AdminUserStatus?> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return AdminVocabularyDropdown<AdminUserStatus>(
      label: 'Status',
      icon: Icons.toggle_on_outlined,
      value: value,
      enabled: enabled,
      error: error,
      items: const [AdminUserStatus.active, AdminUserStatus.inactive],
      labelOf: (status) => status.label,
      onChanged: onChanged,
    );
  }
}

/// A boolean, boxed so it lines up with the field beside it rather than
/// floating at a different height.
class AdminSwitchField extends StatelessWidget {
  const AdminSwitchField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.enabled,
    required this.onLabel,
    required this.offLabel,
    this.onIcon = Icons.check_circle_outline_rounded,
    this.offIcon = Icons.remove_circle_outline_rounded,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final String onLabel;
  final String offLabel;
  final IconData onIcon;
  final IconData offIcon;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminFieldLabel(label),
        const SizedBox(height: AdminTokens.space2),
        InkWell(
          onTap: enabled ? () => onChanged(!value) : null,
          borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AdminTokens.space4,
              vertical: AdminTokens.space2,
            ),
            decoration: BoxDecoration(
              color: tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
              border: Border.all(
                color: value
                    ? tokens.success.withValues(alpha: 0.45)
                    : tokens.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  value ? onIcon : offIcon,
                  size: 18,
                  color: value ? tokens.success : tokens.textMuted,
                ),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Text(
                    value ? onLabel : offLabel,
                    style: TextStyle(
                      color: value ? tokens.textPrimary : tokens.textMuted,
                      fontSize: 13.5,
                      fontWeight: value ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: enabled ? onChanged : null,
                  activeThumbColor: Colors.white,
                  activeTrackColor: tokens.success,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A value the route will not accept, shown rather than offered.
class AdminReadOnlyField extends StatelessWidget {
  const AdminReadOnlyField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.note,
  });

  final String label;
  final String? value;
  final IconData icon;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final text = (value ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminFieldLabel(label),
        const SizedBox(height: AdminTokens.space2),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AdminTokens.space4,
            vertical: AdminTokens.space3 + 3,
          ),
          decoration: BoxDecoration(
            color: tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: tokens.textMuted),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                child: Text(
                  text.isEmpty ? '—' : text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text.isEmpty ? tokens.textMuted : tokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: text.isEmpty
                        ? FontWeight.w400
                        : FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.lock_outline_rounded,
                size: 15,
                color: tokens.textMuted,
              ),
            ],
          ),
        ),
        if (note != null) ...[
          const SizedBox(height: 6),
          Text(
            note!,
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

/// Two fields side by side on a wide dialog, stacked on a narrow one.
class AdminFieldPair extends StatelessWidget {
  const AdminFieldPair({
    super.key,
    required this.narrow,
    required this.first,
    required this.second,
  });

  final bool narrow;
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          first,
          const SizedBox(height: AdminTokens.space4),
          second,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: AdminTokens.space4),
        Expanded(child: second),
      ],
    );
  }
}

class AdminFormSection extends StatelessWidget {
  const AdminFormSection({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: AdminTokens.space3),
        Text(
          label,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(width: AdminTokens.space3),
        Expanded(child: Divider(color: tokens.border, height: 1)),
      ],
    );
  }
}

class AdminFormHeader extends StatelessWidget {
  const AdminFormHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onClose,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AdminTokens.space5,
        AdminTokens.space5,
        AdminTokens.space3,
        AdminTokens.space4,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
              color: tokens.accentSoft,
            ),
            child: Icon(icon, size: 20, color: tokens.accent),
          ),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: tokens.textMuted,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class AdminFormFooter extends StatelessWidget {
  const AdminFormFooter({
    super.key,
    required this.saving,
    required this.submitLabel,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool saving;
  final String submitLabel;
  final VoidCallback? onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space5),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        border: Border(top: BorderSide(color: tokens.border)),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AdminTokens.radiusXl),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
          const SizedBox(width: AdminTokens.space3),
          FilledButton(
            onPressed: saving ? null : onSubmit,
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(submitLabel),
          ),
        ],
      ),
    );
  }
}

class AdminFormErrorBanner extends StatelessWidget {
  const AdminFormErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: tokens.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: tokens.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: tokens.danger),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: tokens.danger,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A neutral explanatory box, for the "this field is fixed after creation"
/// notices the update-restricted forms carry.
class AdminFormNote extends StatelessWidget {
  const AdminFormNote({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: tokens.textMuted),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
