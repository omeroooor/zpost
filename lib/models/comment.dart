import 'author.dart';
import 'package:flutter/foundation.dart';

class Comment {
  final String id;
  final Author author;
  final String content;
  final DateTime createdAt;
  final String postId;
  final DateTime? updatedAt;

  Comment({
    required this.id,
    required this.author,
    required this.content,
    required this.createdAt,
    required this.postId,
    this.updatedAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    try {
      final authorData = json['author'];
      final authorName = json['authorName'];

      Author author;
      if (authorData != null) {
        if (authorData is String) {
          author = Author(
            publicKeyHash: authorData,
            name: authorName,
            image: json['authorImage'],
          );
        } else {
          author = Author.fromJson(authorData);
        }
      } else {
        throw FormatException('Author data is missing in comment JSON');
      }

      String commentId = '';
      if (json.containsKey('_id')) {
        commentId = json['_id'].toString();
      } else if (json.containsKey('id')) {
        commentId = json['id'].toString();
      } else {
        throw FormatException('Comment ID is missing');
      }

      return Comment(
        id: commentId,
        author: author,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        postId: json['post'] as String,
        updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      );
    } catch (e, stackTrace) {
      debugPrint('Error parsing comment: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('Comment data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'author': author.toJson(),
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'post': postId,
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }
}
