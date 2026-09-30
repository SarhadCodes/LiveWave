class CastMember {
  final int id;
  final String name;
  final String character;
  final String profilePath;

  const CastMember({
    required this.id,
    required this.name,
    required this.character,
    required this.profilePath,
  });

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      id: json['id'] ?? 0,
      name: (json['name'] ?? '').toString(),
      character: (json['character'] ?? '').toString(),
      profilePath: (json['profile_path'] ?? '').toString(),
    );
  }
}
