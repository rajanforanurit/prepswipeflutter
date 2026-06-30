class CurrentAffairModel {
  final String? id;
  final String title;
  final String date;
  final String subject;
  final String? imgUrl;
  final String overview;
  final List<String> highlights;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CurrentAffairModel({
    this.id,
    required this.title,
    required this.date,
    required this.subject,
    this.imgUrl,
    required this.overview,
    this.highlights = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory CurrentAffairModel.fromJson(Map<String, dynamic> json) {
    return CurrentAffairModel(
      id: json['_id'] ?? json['id'],
      title: json['title'] ?? '',
      date: json['date'] ?? '',
      subject: json['subject'] ?? '',
      imgUrl: json['imgUrl'],
      overview: json['overview'] ?? '',
      highlights: json['highlights'] != null
          ? List<String>.from(json['highlights'])
          : const [],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'title': title,
      'date': date,
      'subject': subject,
      'imgUrl': imgUrl,
      'overview': overview,
      'highlights': highlights,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }
}
