class NewsModel {
  final String title;
  final String description;
  final String source;
  final DateTime createdAt;
  final String? category;
  final bool? isTrending;
  final String? imageUrl;
  final String? url;

  NewsModel({
    required this.title,
    required this.description,
    required this.source,
    required this.createdAt,
    this.category,
    this.isTrending,
    this.imageUrl,
    this.url,
  });

  factory NewsModel.fromJson(Map<String, dynamic> json) {
    String parsedSource = '';
    final dynamic sourceField = json['source'];
    if (sourceField is String) {
      parsedSource = sourceField;
    } else if (sourceField is Map<String, dynamic>) {
      parsedSource = sourceField['name'] ?? '';
    }

    return NewsModel(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      source: parsedSource,
      createdAt: DateTime.tryParse(
            json['created_at'] ?? json['publishedAt'] ?? '',
          ) ??
          DateTime.now(),
      category: json['category'],
      isTrending: json['is_trending'] ?? false,
      imageUrl: json['image_url'] ?? json['urlToImage'],
      url: json['url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'source': source,
      'created_at': createdAt.toIso8601String(),
      'category': category,
      'is_trending': isTrending,
      'image_url': imageUrl,
      'url': url,
    };
  }
}
