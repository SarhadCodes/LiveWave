import 'dart:convert';

class Channel {
  final String id;
  final String name;
  final String logo;
  final String _encodedStream; // Obfuscated internally
  final String category;
  final String kurdishCategory;
  final bool isLive;
  final bool isActive;
  final int order;
  final bool isFavorite;

  // Security Key for memory obfuscation
  static const String _securityKey = "L1v3W4v3_Secur1ty_2024";

  Channel({
    required this.id,
    required this.name,
    required this.logo,
    required String stream, // Raw stream in constructor
    required this.category,
    required this.kurdishCategory,
    required this.isLive,
    required this.isActive,
    required this.order,
    this.isFavorite = false,
  }) : _encodedStream = _obfuscate(stream);

  /// Get the actual stream URL only when needed (Anti-Sniffing)
  String get stream => _deobfuscate(_encodedStream);

  // Simple XOR Obfuscation to hide links from HttpCanary memory scanning
  static String _obfuscate(String input) {
    if (input.isEmpty) return "";
    List<int> bytes = utf8.encode(input);
    List<int> keyBytes = utf8.encode(_securityKey);
    List<int> result = [];
    for (int i = 0; i < bytes.length; i++) {
      result.add(bytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return base64.encode(result);
  }

  static String _deobfuscate(String input) {
    if (input.isEmpty) return "";
    try {
      List<int> bytes = base64.decode(input);
      List<int> keyBytes = utf8.encode(_securityKey);
      List<int> result = [];
      for (int i = 0; i < bytes.length; i++) {
        result.add(bytes[i] ^ keyBytes[i % keyBytes.length]);
      }
      return utf8.decode(result);
    } catch (e) {
      return "";
    }
  }

  // Helper to get category based on language
  String getDisplayCategory(String language) {
    if (language == 'ku') {
      return kurdishCategory;
    }
    return category;
  }

  factory Channel.fromXtream({
    required int streamId,
    required String name,
    required String logo,
    required String streamUrl,
    required String category,
    required int order,
  }) {
    return Channel(
      id: 'xtream_$streamId',
      name: name,
      logo: logo,
      stream: streamUrl,
      category: category,
      kurdishCategory: category,
      isLive: true,
      isActive: true,
      order: order,
    );
  }

  // Factory constructor to create Channel from Firestore document
  factory Channel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return Channel(
      id: documentId,
      name: data['name'] ?? '',
      logo: data['logo'] ?? '',
      stream: data['stream'] ?? '',
      category: data['category'] ?? 'General',
      kurdishCategory: data['Kcategory'] ?? '',
      isLive: data['isLive'] ?? false,
      isActive: data['isActive'] ?? false,
      order: data['order'] ?? 0,
      isFavorite: data['isFavorite'] ?? false,
    );
  }

  // Convert Channel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'logo': logo,
      'stream': stream,
      'category': category,
      'Kcategory': kurdishCategory,
      'isLive': isLive,
      'isActive': isActive,
      'order': order,
      'isFavorite': isFavorite,
    };
  }

  // CopyWith method for immutability
  Channel copyWith({
    String? id,
    String? name,
    String? logo,
    String? stream,
    String? category,
    String? kurdishCategory,
    bool? isLive,
    bool? isActive,
    int? order,
    bool? isFavorite,
  }) {
    return Channel(
      id: id ?? this.id,
      name: name ?? this.name,
      logo: logo ?? this.logo,
      stream: stream ?? (this.stream),
      category: category ?? this.category,
      kurdishCategory: kurdishCategory ?? this.kurdishCategory,
      isLive: isLive ?? this.isLive,
      isActive: isActive ?? this.isActive,
      order: order ?? this.order,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
