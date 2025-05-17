import 'package:flutter/foundation.dart';
import 'author.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

class Post {
  final String id;
  final Author author;
  final String content;
  final String? contentHash;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? mediaPath;
  final String? originalMediaPath; // Original path from the imported file
  final String? mediaType;
  final String? mediaChecksum;
  final int reputationPoints;
  final bool isConfirmed;
  final bool isDraft;
  final String? hashedId;
  final String? name;
  final String? description;

  Post({
    required this.id,
    required this.author,
    required this.content,
    this.contentHash,
    required this.createdAt,
    this.updatedAt,
    this.mediaPath,
    this.originalMediaPath,
    this.mediaType,
    this.mediaChecksum,
    this.reputationPoints = 0,
    this.isConfirmed = false,
    this.isDraft = false,
    this.hashedId,
    this.name,
    this.description,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    try {
      final authorData = json['author'];
      final authorName = json['authorName'];
      
      Author author;
      if (authorData != null) {
        if (authorData is String) {
          // If author is just a public key hash
          author = Author(
            publicKeyHash: authorData,
            name: authorName,
            image: json['authorImage'],
          );
        } else {
          // If author is a full object
          author = Author.fromJson(authorData);
        }
      } else {
        throw FormatException('Author data is missing in post JSON');
      }

      String postId = '';
      if (json.containsKey('_id')) {
        postId = json['_id'].toString();
      } else if (json.containsKey('id')) {
        postId = json['id'].toString();
      } else {
        throw FormatException('Post ID is missing');
      }

      return Post(
        id: postId,
        author: author,
        content: json['content'] as String,
        contentHash: json['contentHash'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
        mediaPath: json['mediaPath'] as String?,
        originalMediaPath: json['originalMediaPath'] as String?,
        mediaType: json['mediaType'] as String?,
        mediaChecksum: json['mediaChecksum'] as String?,
        reputationPoints: json['reputationPoints'] as int? ?? 0,
        isConfirmed: json['isConfirmed'] as bool? ?? false,
        isDraft: json['isDraft'] as bool? ?? false,
        hashedId: json['hashedId'] as String?,
        name: json['name'] as String?,
        description: json['description'] as String?,
      );
    } catch (e, stackTrace) {
      debugPrint('Error parsing post: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('Post data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'author': author.toJson(),
      'content': content,
      'contentHash': contentHash,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'mediaPath': mediaPath,
      'originalMediaPath': originalMediaPath,
      'mediaType': mediaType,
      'mediaChecksum': mediaChecksum,
      'reputationPoints': reputationPoints,
      'isConfirmed': isConfirmed,
      'isDraft': isDraft,
      'hashedId': hashedId,
      'name': name,
      'description': description,
    };
  }

  // Export to W3-S-POST-NFT format
  Map<String, dynamic> toW3SimplePostNFT() {
    final mediaFileName = mediaPath != null ? path.basename(originalMediaPath ?? mediaPath!) : null;
    return {
      'name': name ?? content,
      'description': description ?? content,
      'text': content,
      'mediaPath': mediaFileName, // Don't include files/ prefix
      'mediaType': mediaType,
      'mediaChecksum': mediaChecksum,
    };
  }

  // Create from W3-S-POST-NFT format
  factory Post.fromW3SimplePostNFT(
    Map<String, dynamic> data,
    Author author, {
    String? localPath,
  }) {
    final originalPath = data['mediaPath'] as String?;
    return Post(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      author: author,
      content: data['text'] as String,
      name: data['name'] as String?,
      description: data['description'] as String?,
      mediaPath: localPath ?? originalPath,
      originalMediaPath: originalPath,
      mediaType: data['mediaType'] as String?,
      mediaChecksum: data['mediaChecksum'] as String?,
      createdAt: DateTime.now(),
    );
  }

  // Compute hash according to W3-S-POST-NFT standard
  String computeHash() {
    final buffer = StringBuffer();
    
    // Add text content
    buffer.write(content);

    // Add media info if present
    if (mediaPath != null) {
      buffer.write(mediaChecksum ?? '');
    }

    final contentString = buffer.toString();
    debugPrint('Computing hash from: $contentString');
    return sha256.convert(utf8.encode(contentString)).toString();
  }

  Post copyWith({
    String? id,
    Author? author,
    String? content,
    String? contentHash,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? mediaPath,
    String? originalMediaPath,
    String? mediaType,
    String? mediaChecksum,
    int? reputationPoints,
    bool? isConfirmed,
    bool? isDraft,
    String? hashedId,
    String? name,
    String? description,
  }) {
    return Post(
      id: id ?? this.id,
      author: author ?? this.author,
      content: content ?? this.content,
      contentHash: contentHash ?? this.contentHash,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mediaPath: mediaPath ?? this.mediaPath,
      originalMediaPath: originalMediaPath ?? this.originalMediaPath,
      mediaType: mediaType ?? this.mediaType,
      mediaChecksum: mediaChecksum ?? this.mediaChecksum,
      reputationPoints: reputationPoints ?? this.reputationPoints,
      isConfirmed: isConfirmed ?? this.isConfirmed,
      isDraft: isDraft ?? this.isDraft,
      hashedId: hashedId ?? this.hashedId,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }
}
