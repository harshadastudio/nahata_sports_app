import 'dart:convert';
import '../core/utils/app_logger.dart';
import 'package:nahata_app/core/network/http_logged.dart' as http;

class ApiService {
  static Future<List<Sport>> fetchSportsByLocation(String location) async {
    final uri = Uri.parse('https://nahatasports.com/sports_list');
    final response = await http.get(uri);

    AppLogger.debug("API response: ${response.body}", name: 'location_api');

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonMap = json.decode(response.body);

      if (!jsonMap.containsKey('data')) {
        throw Exception('No data found in API response');
      }

      final availableKeys = jsonMap['data'].keys;
      AppLogger.debug('Requested location: "$location"', name: 'location_api');
      AppLogger.debug('Available keys: $availableKeys', name: 'location_api');

      final matchedKey = availableKeys.firstWhere(
            (k) => k.toLowerCase().trim() == location.toLowerCase().trim(),
        orElse: () => throw Exception('No data for "$location"'),
      );

      final List<dynamic> sportsList = jsonMap['data'][matchedKey];

      return sportsList.map((e) => Sport.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load sports');
    }
  }




}
class Sport {
  final String name;
  final String imageUrl;

  Sport({required this.name, required this.imageUrl});

  factory Sport.fromJson(Map<String, dynamic> json) {
    return Sport(
      name: json['sport_name'] ?? 'Unknown',
      imageUrl: json['image'] ?? '',
    );
  }
}
