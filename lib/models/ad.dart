class Ad {
  final String id;
  final String title;
  final String kurdishTitle;
  final String description;
  final String kurdishDescription;
  final String imageUrl;
  final String? actionUrl;
  final int order;
  final bool isActive;
  final List<String> badges;

  Ad({
    required this.id,
    required this.title,
    required this.kurdishTitle,
    required this.description,
    required this.kurdishDescription,
    required this.imageUrl,
    this.actionUrl,
    required this.order,
    required this.isActive,
    this.badges = const [],
  });

  // Helper to get title based on language
  String getDisplayTitle(String language) {
    if (language == 'ku' && kurdishTitle.isNotEmpty) {
      return kurdishTitle;
    }
    return title;
  }

  // Helper to get description based on language
  String getDisplayDescription(String language) {
    if (language == 'ku' && kurdishDescription.isNotEmpty) {
      return kurdishDescription;
    }
    return description;
  }

  // Factory constructor to create Ad from Firestore document
  factory Ad.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Ad(
      id: documentId,
      title: data['title'] ?? '',
      kurdishTitle: data['Ktitle'] ?? '',
      description: data['description'] ?? '',
      kurdishDescription: data['kdescription'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      actionUrl: data['actionUrl'],
      order: data['order'] ?? 0,
      isActive: data['isActive'] ?? false,
      badges: data['badges'] != null 
          ? List<String>.from(data['badges']) 
          : [],
    );
  }

  // Convert Ad to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'Ktitle': kurdishTitle,
      'description': description,
      'kdescription': kurdishDescription,
      'imageUrl': imageUrl,
      'actionUrl': actionUrl,
      'order': order,
      'isActive': isActive,
      'badges': badges,
    };
  }

  // CopyWith method for immutability
  Ad copyWith({
    String? id,
    String? title,
    String? kurdishTitle,
    String? description,
    String? kurdishDescription,
    String? imageUrl,
    String? actionUrl,
    int? order,
    bool? isActive,
    List<String>? badges,
  }) {
    return Ad(
      id: id ?? this.id,
      title: title ?? this.title,
      kurdishTitle: kurdishTitle ?? this.kurdishTitle,
      description: description ?? this.description,
      kurdishDescription: kurdishDescription ?? this.kurdishDescription,
      imageUrl: imageUrl ?? this.imageUrl,
      actionUrl: actionUrl ?? this.actionUrl,
      order: order ?? this.order,
      isActive: isActive ?? this.isActive,
      badges: badges ?? this.badges,
    );
  }
}
