import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_coach.dart';
import '../state/employee_coaches_controller.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_forms.dart';
import '../widgets/employee_list_scaffold.dart';

/// Coaches Management — a directory, not an editor.
class EmployeeCoachesPage extends StatefulWidget {
  const EmployeeCoachesPage({super.key});

  @override
  State<EmployeeCoachesPage> createState() => _EmployeeCoachesPageState();
}

class _EmployeeCoachesPageState extends State<EmployeeCoachesPage> {
  late final EmployeeCoachesController _controller =
      EmployeeCoachesController(EmployeeDashboardRepositoryImpl());
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wrapped so the empty-state copy tracks the search.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => EmployeeListScaffold<EmployeeCoach>(
        title: 'Coaches',
        controller: _controller,
        subtitle: () =>
            '${_controller.total} coach${_controller.total == 1 ? '' : 'es'}',
        scopeNotice: 'Coaches attached to your sports complex.',
        filters: EmployeeSearchBar(
          controller: _search,
          hintText: 'Search coaches by name',
          onChanged: _controller.onSearchChanged,
          onClear: _controller.clearSearch,
        ),
        itemBuilder: (context, coach) => _coachCard(coach),
        emptyIcon: Icons.sports_outlined,
        emptyTitle: 'No coaches found',
        emptyMessage: _controller.isFiltered
            ? 'No coach matches that search.'
            : 'Coaches added to your complex by an admin will show up here.',
      ),
    );
  }

  Widget _coachCard(EmployeeCoach coach) {
    return EmployeeCard(
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space3),
      accentColor: coach.isActive
          ? EmployeeTokens.success
          : EmployeeTokens.textMuted,
      onTap: () => _openDetail(coach),
      child: Row(
        children: [
          EmployeeAvatar(initial: coach.initials, radius: 21),
          const SizedBox(width: EmployeeTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coach.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: EmployeeTokens.textDark,
                  ),
                ),
                if (coach.email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    coach.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: EmployeeTokens.textMuted,
                    ),
                  ),
                ],
                if (coach.sports.isNotEmpty) ...[
                  const SizedBox(height: EmployeeTokens.space2),
                  Text(
                    coach.sportsLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: EmployeeTokens.textBody,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: EmployeeTokens.space2),
          EmployeeChip(label: coach.status, dense: true),
        ],
      ),
    );
  }

  Future<void> _openDetail(EmployeeCoach coach) {
    return showEmployeeSheet<void>(
      context: context,
      title: coach.displayName,
      subtitle: coach.sportsLabel == '—' ? null : coach.sportsLabel,
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EmployeeAvatar(initial: coach.initials, radius: 28),
              const SizedBox(width: EmployeeTokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      coach.displayName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: EmployeeTokens.textDark,
                      ),
                    ),
                    const SizedBox(height: EmployeeTokens.space2),
                    EmployeeChip(label: coach.status),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: EmployeeTokens.space5),
          EmployeeDetailRow(label: 'Email', value: coach.email),
          EmployeeDetailRow(label: 'Phone', value: coach.phone),
          EmployeeDetailRow(label: 'Sports', value: coach.sportsLabel),
          if ((coach.experience ?? '').isNotEmpty)
            EmployeeDetailRow(
              label: 'Experience',
              value: '${coach.experience} years',
            ),
          EmployeeDetailRow(label: 'Joined', value: coach.joinedLabel),
          if ((coach.bio ?? '').isNotEmpty) ...[
            const SizedBox(height: EmployeeTokens.space4),
            const Text(
              'BIO',
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 0.9,
                fontWeight: FontWeight.w700,
                color: EmployeeTokens.textMuted,
              ),
            ),
            const SizedBox(height: EmployeeTokens.space2),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(EmployeeTokens.space3),
              decoration: BoxDecoration(
                color: EmployeeTokens.canvas,
                borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
              ),
              child: Text(
                coach.bio!,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: EmployeeTokens.textBody,
                ),
              ),
            ),
          ],
          const SizedBox(height: EmployeeTokens.space5),
          Container(
            padding: const EdgeInsets.all(EmployeeTokens.space3),
            decoration: BoxDecoration(
              color: EmployeeTokens.canvas,
              borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: EmployeeTokens.textMuted,
                ),
                SizedBox(width: EmployeeTokens.space2),
                Expanded(
                  child: Text(
                    'Coach records are created and maintained by an admin. '
                    'Ask them to change anything here.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: EmployeeTokens.textBody,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
