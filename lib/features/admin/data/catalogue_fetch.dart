import '../../../core/network/api_response.dart';
import '../core/admin_log.dart';

/// Reads every page of a list route that the console consumes as one catalogue.
///
/// Three of the confirmed URLs carry `page=1&limit=100`
/// (`/sports`, `/sports-complexes`, `/coaches`) while the modules above them
/// filter, sort and page locally over the whole set. Sending the confirmed
/// limit and stopping there would quietly cut the catalogue off at a hundred
/// rows, which looks exactly like "there are only a hundred".
///
/// The walk is deliberately envelope-agnostic, because these routes' pagination
/// counters have never been captured:
///
///  * it asks for the next page only when the last one came back **full**, so a
///    genuinely unpaginated route costs exactly one request;
///  * it stops when a page adds no row it has not already seen, so a backend
///    that ignores `page` and re-serves page one terminates instead of looping;
///  * it is capped at [maxPages], so a backend that echoes a full page forever
///    cannot spin.
Future<List<T>> fetchCatalogue<T>({
  required Future<ApiResponse> Function(int page) request,
  required List<T> Function(ApiResponse response) parse,
  required Object? Function(T row) identity,
  int limit = 100,
  int maxPages = 20,
  String label = 'rows',
}) async {
  final rows = <T>[];
  final seen = <Object>{};

  for (var page = 1; page <= maxPages; page++) {
    final response = await request(page);
    if (!response.isOk) {
      // Page one failing is a real error and belongs to the caller. A later
      // page failing means the catalogue is short, not broken — keep what we
      // have rather than losing the first hundred rows to the hundred-and-first.
      if (page == 1) throw response.toException();
      AdminLog.data('Catalogue $label: page $page failed, keeping ${rows.length}');
      break;
    }

    final batch = parse(response);
    var added = 0;
    for (final row in batch) {
      final id = identity(row);
      // A row with no id cannot be deduped; keep it rather than dropping it,
      // and let the full-page test below decide when to stop.
      if (id == null) {
        rows.add(row);
        added++;
        continue;
      }
      if (seen.add(id)) {
        rows.add(row);
        added++;
      }
    }

    if (batch.length < limit || added == 0) break;

    if (page == maxPages) {
      AdminLog.data(
        'Catalogue $label: stopped at the $maxPages-page cap (${rows.length})',
      );
    }
  }

  return rows;
}