import 'package:flutter/foundation.dart';

class Supporter {
  final String profileId;
  final int sentRp;
  final String? name;
  final String? image;

  Supporter({
    required this.profileId,
    required this.sentRp,
    this.name,
    this.image,
  });

  factory Supporter.fromJson(Map<String, dynamic> json) {
    try {
      return Supporter(
        profileId: json['profile_id'] as String,
        sentRp: json['sent_rp'] as int,
        name: json['name'] as String?,
        image: json['image'] as String?,
      );
    } catch (e, stackTrace) {
      debugPrint('Error parsing supporter: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('Supporter data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_id': profileId,
      'sent_rp': sentRp,
      'name': name,
      'image': image,
    };
  }
}

class SupportersInfo {
  final String contentHash;
  final List<Supporter> supporters;
  final int totalSupporters;
  final int totalReceivedRp;
  final DateTime? lastUpdated;

  SupportersInfo({
    required this.contentHash,
    required this.supporters,
    required this.totalSupporters,
    required this.totalReceivedRp,
    this.lastUpdated,
  });

  factory SupportersInfo.fromJson(Map<String, dynamic> json) {
    try {
      return SupportersInfo(
        contentHash: json['contentHash'] as String,
        supporters: (json['supporters'] as List)
            .map((e) => Supporter.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalSupporters: json['total_supporters'] as int,
        totalReceivedRp: json['total_received_rp'] as int,
        lastUpdated: json['last_updated'] != null
            ? DateTime.parse(json['last_updated'] as String)
            : null,
      );
    } catch (e, stackTrace) {
      debugPrint('Error parsing supporters info: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('Supporters info data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'contentHash': contentHash,
      'supporters': supporters.map((e) => e.toJson()).toList(),
      'total_supporters': totalSupporters,
      'total_received_rp': totalReceivedRp,
      'last_updated': lastUpdated?.toIso8601String(),
    };
  }
}
