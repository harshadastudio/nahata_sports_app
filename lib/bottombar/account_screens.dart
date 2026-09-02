import 'package:flutter/material.dart';

import '../core/network/api_exception.dart';
import '../core/utils/app_logger.dart';
import '../models/enrollment_model.dart';
import '../models/feedback_thread_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/coaching_repository.dart';
import '../repositories/user_repository.dart';

const Color _navy = Color(0xFF1A237E);

/// Shared scaffolding for the account screens below.
///
/// Each one is a single authenticated GET rendered as a list, so they share
/// the same three states — loading, a failure the user can retry, and an empty
/// result that says so rather than looking broken. Keeping that in one place
/// is what stops a failed call anywhere here from showing a blank screen.
class _ListScreen<T> extends StatefulWidget {
  const _ListScreen({
    super.key,
    required this.title,
    required this.load,
    required this.itemBuilder,
    required this.emptyMessage,
    this.emptyIcon = Icons.inbox_outlined,
    this.header,
  });

  final String title;
  final Future<List<T>> Function() load;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String emptyMessage;
  final IconData emptyIcon;
  final Widget? header;

  @override
  State<_ListScreen<T>> createState() => _ListScreenState<T>();
}

class _ListScreenState<T> extends State<_ListScreen<T>> {
  List<T> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await widget.load();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e, s) {
      AppLogger.error(
        '${widget.title} failed',
        name: 'Account',
        error: e,
        stackTrace: s,
      );
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load this. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return _Message(
        icon: Icons.cloud_off,
        message: _error!,
        actionLabel: 'Try again',
        onAction: _load,
      );
    }

    if (_items.isEmpty) {
      return _Message(icon: widget.emptyIcon, message: widget.emptyMessage);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _items.length + (widget.header == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (widget.header != null) {
          if (index == 0) return widget.header!;
          return widget.itemBuilder(context, _items[index - 1]);
        }
        return widget.itemBuilder(context, _items[index]);
      },
    );
  }
}

/// A full-height state message. Scrollable so pull-to-refresh still works when
/// there is nothing in the list to drag.
class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 140),
        Icon(icon, size: 48, color: Colors.black26),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 18),
          Center(
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(backgroundColor: _navy),
              child: Text(
                actionLabel!,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

Widget _card({required Widget child}) => Container(
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
  ),
  child: child,
);

Widget _pill(String label, Color color) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(
    label,
    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
  ),
);

// ---------------------------------------------------------------------------
// GET /fees/my
// ---------------------------------------------------------------------------

/// `GET /fees/my` — the student's approved coaching passes.
///
/// The pass code and QR URL are built server-side; nothing here composes them.
class GatePassesScreen extends StatelessWidget {
  const GatePassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ListScreen<GatePassModel>(
      title: 'Coaching Passes',
      emptyIcon: Icons.qr_code_2_outlined,
      emptyMessage:
          'No coaching passes yet.\nA pass appears here once your enrollment is approved.',
      load: UserRepository.instance.fetchMyGatePasses,
      itemBuilder: (context, pass) {
        final schedule = [
          if (pass.batchDays != null) pass.batchDays,
          if (pass.startTime != null && pass.endTime != null)
            '${pass.startTime} – ${pass.endTime}',
        ].whereType<String>().join(' · ');

        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pass.sportName ?? pass.batchName ?? 'Coaching pass',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        if (pass.batchName != null)
                          Text(
                            pass.batchName!,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _pill(
                    pass.isValid ? 'Valid' : 'Expired',
                    pass.isValid ? Colors.green : Colors.red,
                  ),
                ],
              ),
              const Divider(height: 20),
              if (pass.passCode != null)
                Row(
                  children: [
                    const Icon(
                      Icons.confirmation_number_outlined,
                      size: 15,
                      color: Colors.black38,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: SelectableText(
                        pass.passCode!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              if (pass.coachName != null) ...[
                const SizedBox(height: 6),
                _line(Icons.person_outline, 'Coach: ${pass.coachName}'),
              ],
              if (schedule.isNotEmpty) ...[
                const SizedBox(height: 6),
                _line(Icons.schedule, schedule),
              ],
              if (pass.validTill != null) ...[
                const SizedBox(height: 6),
                _line(
                  Icons.event_available_outlined,
                  'Valid till ${pass.validTill}',
                ),
              ],
              if (pass.qrCode != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      pass.qrCode!,
                      height: 148,
                      width: 148,
                      fit: BoxFit.contain,
                      // A pass is still usable from its code alone, so a QR
                      // that will not load must not blank the whole card.
                      errorBuilder: (_, _, _) => const SizedBox(
                        height: 60,
                        child: Center(
                          child: Text(
                            'QR unavailable — show the pass code above.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.black45,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static Widget _line(IconData icon, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 15, color: Colors.black38),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 12.5, color: Colors.black54),
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// GET /coaching-enquiries/my-enquiries
// ---------------------------------------------------------------------------

/// `GET /coaching-enquiries/my-enquiries` — what the user has asked about.
class MyEnquiriesScreen extends StatelessWidget {
  const MyEnquiriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ListScreen<MyEnquiry>(
      title: 'My Enquiries',
      emptyIcon: Icons.help_outline,
      emptyMessage:
          'No enquiries yet.\nAsk about a batch from any coach\'s page and it will appear here.',
      load: () => CoachingRepository.instance.fetchMyEnquiries(),
      itemBuilder: (context, enquiry) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    enquiry.sportName ?? enquiry.batchName ?? 'Enquiry',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (enquiry.status != null)
                  _pill(
                    enquiry.status!,
                    enquiry.isPending ? Colors.orange : Colors.green,
                  ),
              ],
            ),
            if (enquiry.batchName != null) ...[
              const SizedBox(height: 3),
              Text(
                enquiry.batchName!,
                style: const TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
            ],
            if (enquiry.coachName != null) ...[
              const SizedBox(height: 6),
              Text(
                'Coach: ${enquiry.coachName}',
                style: const TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
            ],
            if (enquiry.message != null) ...[
              const SizedBox(height: 8),
              Text(
                enquiry.message!,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
            if (enquiry.referenceNumber != null) ...[
              const SizedBox(height: 10),
              // Worth selecting: it is what the user quotes on the phone.
              SelectableText(
                'Ref: ${enquiry.referenceNumber}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Colors.black45,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// GET /students/me/enrollments  (list) — see also Enrollments in morescreen
// ---------------------------------------------------------------------------

/// `GET /students/me/enrollments`, presented as cards rather than the plain
/// list tiles the older screen uses.
class MyEnrollmentsScreen extends StatelessWidget {
  const MyEnrollmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ListScreen<EnrollmentModel>(
      title: 'My Enrollments',
      emptyIcon: Icons.school_outlined,
      emptyMessage: 'You are not enrolled in any batch yet.',
      load: UserRepository.instance.fetchMyEnrollments,
      itemBuilder: (context, row) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.sportName ?? row.batchName ?? 'Enrollment',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                _pill(
                  row.isActive ? 'Active' : (row.status ?? 'Inactive'),
                  row.isActive ? Colors.green : Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in [
              if (row.batchName != null) 'Batch: ${row.batchName}',
              if (row.coachName != null) 'Coach: ${row.coachName}',
              if (row.complexName != null) 'Venue: ${row.complexName}',
              if (row.enrollmentDate != null) 'Enrolled: ${row.enrollmentDate}',
              if (row.validTill != null) 'Valid till: ${row.validTill}',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  line,
                  style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (row.approvalStatus != null)
                  _pill(
                    row.approvalStatus!,
                    row.isApproved ? Colors.green : Colors.orange,
                  ),
                const SizedBox(width: 8),
                if (row.paymentStatus != null)
                  _pill(
                    row.paymentStatus!,
                    row.isPaid ? Colors.green : Colors.red,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PUT /auth/change-password
// ---------------------------------------------------------------------------

/// `PUT /auth/change-password`.
///
/// The endpoint answers 403 for accounts whose password an administrator owns
/// (staff logins and complex admins) with the message to show them, so that
/// case needs no client-side role check.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _saving = false;
  bool _hideCurrent = true;
  bool _hideNext = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final message = await AuthRepository.instance.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      // The server's own words: a wrong current password and an
      // admin-managed account need different things from the user.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e, s) {
      AppLogger.error(
        'Change password failed',
        name: 'Auth',
        error: e,
        stackTrace: s,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text(
          'Change Password',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _card(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field(
                  label: 'Current password',
                  controller: _current,
                  obscure: _hideCurrent,
                  onToggle: () => setState(() => _hideCurrent = !_hideCurrent),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Enter your current password.'
                      : null,
                ),
                _field(
                  label: 'New password',
                  controller: _next,
                  obscure: _hideNext,
                  onToggle: () => setState(() => _hideNext = !_hideNext),
                  // Mirrors the backend's own rule, so a password it would
                  // refuse never costs a round trip.
                  helper: 'At least 6 characters.',
                  validator: (v) {
                    if (v == null || v.length < 6) {
                      return 'Use at least 6 characters.';
                    }
                    if (v == _current.text) {
                      return 'Choose a different password.';
                    }
                    return null;
                  },
                ),
                _field(
                  label: 'Confirm new password',
                  controller: _confirm,
                  obscure: _hideNext,
                  validator: (v) =>
                      v != _next.text ? 'The passwords do not match.' : null,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Update Password',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required String? Function(String?) validator,
    VoidCallback? onToggle,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        enabled: !_saving,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          suffixIcon: onToggle == null
              ? null
              : IconButton(
                  onPressed: onToggle,
                  icon: Icon(
                    obscure ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                  ),
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// POST /user-feedback  +  GET /user-feedback/mine
// ---------------------------------------------------------------------------

/// The user's feedback threads, with a composer for a new one.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  List<FeedbackThread> _threads = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final threads = await UserRepository.instance.fetchMyFeedbackThreads();
      if (!mounted) return;
      setState(() {
        _threads = threads;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e, s) {
      AppLogger.error(
        'Feedback list failed',
        name: 'Account',
        error: e,
        stackTrace: s,
      );
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load your feedback. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _compose() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _FeedbackComposer(),
    );

    if (sent == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text(
          'Feedback',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _compose,
        backgroundColor: _navy,
        icon: const Icon(Icons.edit_outlined, color: Colors.white),
        label: const Text(
          'Write feedback',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return _Message(
        icon: Icons.cloud_off,
        message: _error!,
        actionLabel: 'Try again',
        onAction: _load,
      );
    }

    if (_threads.isEmpty) {
      return const _Message(
        icon: Icons.forum_outlined,
        message:
            'No feedback yet.\nTell us what is working and what is not — we read every message.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: _threads.length,
      itemBuilder: (context, index) {
        final thread = _threads[index];

        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      thread.subject ?? 'Feedback',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (thread.status != null)
                    _pill(
                      thread.status!,
                      thread.isResolved ? Colors.green : Colors.orange,
                    ),
                ],
              ),
              if (thread.rating != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < thread.rating! ? Icons.star : Icons.star_border,
                      size: 15,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ),
              ],
              if (thread.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  thread.message!,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ],
              // The replies are the reason to open this screen, so they are
              // shown inline rather than behind another tap.
              for (final reply in thread.messages.where((m) => m.isFromAdmin))
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reply.senderName ?? 'Nahata Sports',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _navy,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        reply.message ?? '',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              if (thread.referenceNumber != null) ...[
                const SizedBox(height: 10),
                SelectableText(
                  'Ref: ${thread.referenceNumber}',
                  style: const TextStyle(fontSize: 11.5, color: Colors.black45),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// `POST /user-feedback` — `{subject, rating, message}`.
class _FeedbackComposer extends StatefulWidget {
  const _FeedbackComposer();

  @override
  State<_FeedbackComposer> createState() => _FeedbackComposerState();
}

class _FeedbackComposerState extends State<_FeedbackComposer> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  int _rating = 0;
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sending = true);

    try {
      final reference = await UserRepository.instance.submitFeedback(
        subject: _subject.text,
        message: _message.text,
        rating: _rating == 0 ? null : _rating,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reference == null
                ? 'Thank you — your feedback has been sent.'
                : 'Thank you — your feedback has been sent. Ref: $reference',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e, s) {
      AppLogger.error(
        'Submit feedback failed',
        name: 'Account',
        error: e,
        stackTrace: s,
      );
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the sheet clear of the keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Write feedback',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subject,
                enabled: !_sending,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Subject',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please add a subject.'
                    : null,
              ),
              const SizedBox(height: 14),
              const Text(
                'Rating (optional)',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => IconButton(
                    onPressed: _sending
                        ? null
                        // Tapping the current star clears it, so an
                        // accidental rating is not stuck on the form.
                        : () => setState(
                            () => _rating = _rating == i + 1 ? 0 : i + 1,
                          ),
                    icon: Icon(
                      i < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ),
              ),
              TextFormField(
                controller: _message,
                enabled: !_sending,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Your feedback',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please write your feedback.'
                    : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _sending
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _sending ? null : _send,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _sending
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Send',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
