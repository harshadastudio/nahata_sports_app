import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/coach_dashboard_model.dart';
import '../repositories/coach_repository.dart';

/// Enquiries assigned to the signed-in coach —
/// `GET /coaching-enquiries/coach/my-enquiries?page=&limit=`.
///
/// The coach is identified by the bearer token, so [userId] is no longer sent;
/// it is kept as an optional parameter so existing call sites still compile.
///
/// Old API (commented out below): `GET coaching-enquiry?user_id=`.
class CoachingEnquiryScreen extends StatefulWidget {
  /// Unused since the migration — the token identifies the coach.
  final int? userId;

  const CoachingEnquiryScreen({super.key, this.userId});

  @override
  State<CoachingEnquiryScreen> createState() => _CoachingEnquiryScreenState();
}

class _CoachingEnquiryScreenState extends State<CoachingEnquiryScreen> {
  static const int _pageSize = 20;

  bool loading = true;
  bool loadingMore = false;
  List<CoachEnquiry> enquiries = const <CoachEnquiry>[];

  int _page = 1;
  int _totalPages = 0;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    fetchEnquiries();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 100 &&
        !loadingMore &&
        _page < _totalPages) {
      _loadMore();
    }
  }

  Future<void> fetchEnquiries() async {
    setState(() => loading = true);

    final result = await CoachRepository.instance
        .fetchMyEnquiryPage(page: 1, limit: _pageSize);

    if (!mounted) return;
    setState(() {
      enquiries = result.items;
      _page = result.page;
      _totalPages = result.totalPages;
      loading = false;
      loadingMore = false;
    });
  }

  Future<void> _loadMore() async {
    setState(() => loadingMore = true);

    final result = await CoachRepository.instance
        .fetchMyEnquiryPage(page: _page + 1, limit: _pageSize);

    if (!mounted) return;
    setState(() {
      enquiries = [...enquiries, ...result.items];
      if (result.items.isNotEmpty) _page = result.page;
      _totalPages = result.totalPages;
      loadingMore = false;
    });
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '';
    return DateFormat('dd MMM yyyy').format(value.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Coaching Enquiries"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchEnquiries,
              child: enquiries.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 200),
                        Center(
                          child: Text(
                            "No enquiries found.",
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: enquiries.length + (loadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == enquiries.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final item = enquiries[index];

                        return Card(
                          color: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.displayName,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black),
                                      ),
                                    ),
                                    if ((item.status ?? '').isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: item.isOpen
                                              ? Colors.orange.shade50
                                              : Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          item.status!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: item.isOpen
                                                ? Colors.orange.shade800
                                                : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                if ((item.sportName ?? '').isNotEmpty)
                                  Text(
                                    "Sport: ${item.sportName}",
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                if ((item.batchName ?? '').isNotEmpty)
                                  Text(
                                    "Batch: ${item.batchName}",
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                const SizedBox(height: 8),

                                if ((item.email ?? '').isNotEmpty)
                                  Text("Email: ${item.email}"),
                                if ((item.phone ?? '').isNotEmpty)
                                  Text("Contact: ${item.phone}"),
                                if ((item.message ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(item.message!),
                                ],
                                const SizedBox(height: 8),

                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (item.createdAt != null)
                                      Text(
                                        "Enquiry Date: "
                                        "${_formatDate(item.createdAt)}",
                                        style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13),
                                      ),
                                    if ((item.referenceNumber ?? '').isNotEmpty)
                                      Text(
                                        item.referenceNumber!,
                                        style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 12),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

// ---------------------- OLD API (commented out) ----------------------
//
// Future<void> fetchEnquiries() async {
//   final url = Uri.parse(
//       "https://nahatasports.com/api/coaching-enquiry?user_id=${widget.userId}");
//
//   try {
//     final response = await http.get(url);
//     final data = jsonDecode(response.body);
//
//     if (data["status"] == 200) {
//       setState(() {
//         enquiries = data["enquiries"] ?? [];
//         loading = false;
//       });
//     } else {
//       setState(() => loading = false);
//     }
//   } catch (e) {
//     setState(() => loading = false);
//   }
// }
//
// The card read: coach_name, sport_name, user_name, user_email, user_contact,
// created_at. Those keys are all still accepted by CoachEnquiry.fromJson.
