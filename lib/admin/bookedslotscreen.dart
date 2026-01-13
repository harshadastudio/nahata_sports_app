import 'package:flutter/material.dart';

import 'notifications/admin_notification.dart';

class BookedSlotsScreen extends StatefulWidget {
  const BookedSlotsScreen({super.key});

  @override
  State<BookedSlotsScreen> createState() => _BookedSlotsScreenState();
}

class _BookedSlotsScreenState extends State<BookedSlotsScreen> {
  final List<CourtResponse> _slots = [];
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  int _page = 1;
  final int _perPage = 10;

  @override
  void initState() {
    super.initState();
    _fetchSlots();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100 &&
          !_loadingMore &&
          _hasMore) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchSlots() async {
    final list = await CourtResponseService.fetchCourtResponses(
      page: _page,
      perPage: _perPage,
    );

    setState(() {
      _slots.addAll(list);
      _loading = false;
      _hasMore = list.length == _perPage;
    });
  }

  Future<void> _loadMore() async {
    _loadingMore = true;
    _page++;

    final list = await CourtResponseService.fetchCourtResponses(
      page: _page,
      perPage: _perPage,
    );

    setState(() {
      _slots.addAll(list);
      _loadingMore = false;
      if (list.length < _perPage) _hasMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Booked Slots"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _slots.isEmpty
          ? const Center(
        child: Text(
          "No booked slots found",
          style: TextStyle(color: Colors.grey),
        ),
      )
          : ListView.builder(
        controller: _scrollController,
        itemCount: _slots.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _slots.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final slot = _slots[index];

          return Card(
            margin: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text(
                slot.courtName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text("Date: ${slot.selectedDate}"),
                  const Text(
                    "Slots:",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),

                  ...slot.slots.map(
                        (s) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        "• ${s.time} (${s.hourType}) - ₹${s.price}",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  Text("Booking ID: ${slot.id}"),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "₹${slot.amount}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    slot.status,
                    style: TextStyle(
                      color: slot.status == "approved"
                          ? Colors.green
                          : Colors.orange,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}


