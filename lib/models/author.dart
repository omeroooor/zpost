import 'package:flutter/foundation.dart';

class Author {
  final String publicKeyHash;
  final String? name;
  final String? image;
  final String? profileImage;

  const Author({
    required this.publicKeyHash,
    this.name,
    this.image,
    this.profileImage,
  });

  factory Author.fromJson(dynamic json) {
    if (json is String) {
      // Handle case where author is just a public key hash string
      return Author(
        publicKeyHash: json,
        name: null,
        image: null,
        profileImage: null,
      );
    }
    
    if (json is! Map<String, dynamic>) {
      throw FormatException('Invalid author data format: $json');
    }
    
    return Author(
      publicKeyHash: json['publicKeyHash'] ?? json['author'] ?? '',
      name: json['name'] as String?,
      image: json['image'] as String?,
      profileImage: json['profileImage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'publicKeyHash': publicKeyHash,
      'name': name,
      'image': image,
      'profileImage': profileImage,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Author &&
          runtimeType == other.runtimeType &&
          publicKeyHash == other.publicKeyHash;

  @override
  int get hashCode => publicKeyHash.hashCode;
}
