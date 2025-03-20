class Service {
  final String createdAt;
  final String description;
  final String duration;
  final int id;
  final String imageUrl;
  final double price;
  final int repetitions;
  final String status;
  final String title;
  final String type;

  Service({
    required this.createdAt,
    required this.description,
    required this.duration,
    required this.id,
    required this.imageUrl,
    required this.price,
    required this.repetitions,
    required this.status,
    required this.title,
    required this.type,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      createdAt: json['created_at'],
      description: json['description'],
      duration: json['duration'],
      id: json['id'],
      imageUrl: json['image_url'],
      price: json['price'].toDouble(),
      repetitions: json['repetitions'],
      status: json['status'],
      title: json['title'],
      type: json['type'],
    );
  }
}