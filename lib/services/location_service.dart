import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static Future<List<Sport>> fetchSportsByLocation(String location) async {
    final uri = Uri.parse('https://nahatasports.com/sports_list');
    final response = await http.get(uri);

    print("API response: ${response.body}");

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonMap = json.decode(response.body);

      if (!jsonMap.containsKey('data')) {
        throw Exception('No data found in API response');
      }

      final availableKeys = jsonMap['data'].keys;
      print('Requested location: "$location"');
      print('Available keys: $availableKeys');

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


