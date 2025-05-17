class Profile {
  final String publicKeyHash;
  final String name;
  final String? image;
  final int reputationPoints;
  final DateTime createdAt;

  Profile({
    required this.publicKeyHash,
    required this.name,
    this.image,
    required this.reputationPoints,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      publicKeyHash: json['publicKeyHash'],
      name: json['name'],
      image: json['image'],
      reputationPoints: json['reputationPoints'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'publicKeyHash': publicKeyHash,
      'name': name,
      'image': image,
      'reputationPoints': reputationPoints,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
