import 'package:flutter/material.dart';

import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';

/// Searchable sports-complex picker.
///
/// The options come from `GET /sports-complexes` — no id is ever hardcoded.
/// Tapping it opens a sheet with a filter box, which behaves the same on a
/// desktop pointer and a phone, unlike an overlay-anchored autocomplete.
class ComplexPickerField extends FormField<SportsComplex> {
  ComplexPickerField({
    super.key,
    required List<SportsComplex> complexes,
    required ViewState state,
    required VoidCallback onReload,
    SportsComplex? initialComplex,
    ValueChanged<SportsComplex?>? onChanged,
    bool enabled = true,
    String? serverError,
    super.validator,
  }) : super(
         initialValue: initialComplex,
         enabled: enabled,
         autovalidateMode: AutovalidateMode.disabled,
         builder: (field) {
           final context = field.context;
           final tokens = AdminTheme.of(context);
           final error = serverError ?? field.errorText;
           final selected = field.value;

           Future<void> pick() async {
             if (!enabled) return;
             AdminLog.ui('Complex picker opened (${complexes.length} options)');

             final chosen = await showModalBottomSheet<SportsComplex>(
               context: context,
               isScrollControlled: true,
               backgroundColor: tokens.surface,
               shape: const RoundedRectangleBorder(
                 borderRadius: BorderRadius.vertical(
                   top: Radius.circular(AdminTokens.radiusXl),
                 ),
               ),
               builder: (_) => _ComplexPickerSheet(
                 complexes: complexes,
                 state: state,
                 onReload: onReload,
                 selectedId: selected?.id,
               ),
             );

             if (chosen == null) return;
             AdminLog.ui('Complex picked → ${chosen.id} (${chosen.name})');
             field.didChange(chosen);
             onChanged?.call(chosen);
           }

           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             mainAxisSize: MainAxisSize.min,
             children: [
               Text(
                 'Sport complex',
                 style: TextStyle(
                   color: tokens.textSecondary,
                   fontSize: 12,
                   fontWeight: FontWeight.w600,
                 ),
               ),
               const SizedBox(height: AdminTokens.space2),
               InkWell(
                 onTap: enabled ? pick : null,
                 borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
                 child: Container(
                   padding: const EdgeInsets.symmetric(
                     horizontal: AdminTokens.space4,
                     vertical: AdminTokens.space3 + 1,
                   ),
                   decoration: BoxDecoration(
                     color: tokens.surfaceAlt,
                     borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
                     border: Border.all(
                       color: error != null ? tokens.danger : tokens.border,
                     ),
                   ),
                   child: Row(
                     children: [
                       Icon(
                         Icons.stadium_outlined,
                         size: 18,
                         color: tokens.textMuted,
                       ),
                       const SizedBox(width: AdminTokens.space3),
                       Expanded(
                         child: Text(
                           selected?.label ??
                               (state.isLoading
                                   ? 'Loading complexes…'
                                   : 'Select a sports complex'),
                           overflow: TextOverflow.ellipsis,
                           style: TextStyle(
                             color: selected == null
                                 ? tokens.textMuted
                                 : tokens.textPrimary,
                             fontSize: 13.5,
                             fontWeight: selected == null
                                 ? FontWeight.w400
                                 : FontWeight.w600,
                           ),
                         ),
                       ),
                       if (state.isLoading)
                         const SizedBox(
                           width: 15,
                           height: 15,
                           child: CircularProgressIndicator(strokeWidth: 2),
                         )
                       else
                         Icon(
                           Icons.expand_more_rounded,
                           size: 18,
                           color: tokens.textMuted,
                         ),
                     ],
                   ),
                 ),
               ),
               if (error != null) ...[
                 const SizedBox(height: 6),
                 Text(
                   error,
                   style: TextStyle(color: tokens.danger, fontSize: 11.5),
                 ),
               ],
               if (state.isFailed) ...[
                 const SizedBox(height: 6),
                 Row(
                   children: [
                     Icon(
                       Icons.error_outline_rounded,
                       size: 13,
                       color: tokens.warning,
                     ),
                     const SizedBox(width: 5),
                     Expanded(
                       child: Text(
                         'Could not load complexes.',
                         style: TextStyle(
                           color: tokens.textMuted,
                           fontSize: 11.5,
                         ),
                       ),
                     ),
                     TextButton(
                       onPressed: onReload,
                       style: TextButton.styleFrom(
                         padding: EdgeInsets.zero,
                         minimumSize: Size.zero,
                         tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                       ),
                       child: const Text(
                         'Retry',
                         style: TextStyle(fontSize: 11.5),
                       ),
                     ),
                   ],
                 ),
               ],
             ],
           );
         },
       );
}

class _ComplexPickerSheet extends StatefulWidget {
  const _ComplexPickerSheet({
    required this.complexes,
    required this.state,
    required this.onReload,
    this.selectedId,
  });

  final List<SportsComplex> complexes;
  final ViewState state;
  final VoidCallback onReload;
  final int? selectedId;

  @override
  State<_ComplexPickerSheet> createState() => _ComplexPickerSheetState();
}

class _ComplexPickerSheetState extends State<_ComplexPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Local filtering — the whole venue list is already in memory, so a debounce
  /// and a round trip would only add latency.
  List<SportsComplex> get _filtered {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.complexes;
    return widget.complexes
        .where((complex) => complex.label.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final results = _filtered;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AdminTokens.space5,
              AdminTokens.space4,
              AdminTokens.space3,
              AdminTokens.space3,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select sports complex',
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
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
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AdminTokens.space5),
            child: TextField(
              controller: _search,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by name or city',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: tokens.textMuted,
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded, size: 16),
                        color: tokens.textMuted,
                      ),
              ),
            ),
          ),
          const SizedBox(height: AdminTokens.space3),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AdminTokens.space6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.complexes.isEmpty
                                ? Icons.cloud_off_rounded
                                : Icons.search_off_rounded,
                            size: 30,
                            color: tokens.textMuted,
                          ),
                          const SizedBox(height: AdminTokens.space3),
                          Text(
                            widget.complexes.isEmpty
                                ? 'No sports complexes available'
                                : 'Nothing matches "$_query"',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: tokens.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          if (widget.complexes.isEmpty) ...[
                            const SizedBox(height: AdminTokens.space4),
                            OutlinedButton.icon(
                              onPressed: () {
                                widget.onReload();
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 17),
                              label: const Text('Reload'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AdminTokens.space4,
                    ),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final complex = results[index];
                      final selected = complex.id == widget.selectedId;

                      return ListTile(
                        onTap: () => Navigator.of(context).pop(complex),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AdminTokens.radiusMd,
                          ),
                        ),
                        selected: selected,
                        selectedTileColor: tokens.accentSoft,
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: tokens.surfaceAlt,
                            borderRadius: BorderRadius.circular(
                              AdminTokens.radiusSm,
                            ),
                          ),
                          child: Icon(
                            Icons.stadium_outlined,
                            size: 17,
                            color: selected ? tokens.accent : tokens.textMuted,
                          ),
                        ),
                        title: Text(
                          complex.name,
                          style: TextStyle(
                            color: selected
                                ? tokens.accent
                                : tokens.textPrimary,
                            fontSize: 13.5,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                        subtitle: complex.city == null
                            ? null
                            : Text(
                                complex.city!,
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                        trailing: selected
                            ? Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: tokens.accent,
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
