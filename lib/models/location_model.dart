class LocationModel {
  final String name;
  final String imageUrl;

  LocationModel({required this.name, required this.imageUrl});

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      name: json['name'],
      imageUrl: json['image_url'],
    );
  }
}
