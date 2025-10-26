import 'package:hive/hive.dart';

part 'event.g.dart';

@HiveType(typeId: 0)
class Event {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String? eventbriteId;
  
  @HiveField(2)
  final String name;
  
  @HiveField(3)
  final String description;
  
  @HiveField(4)
  final DateTime startDate;
  
  @HiveField(5)
  final DateTime endDate;
  
  @HiveField(6)
  final String venue;
  
  @HiveField(7)
  final String status; // 'draft' | 'published'
  
  @HiveField(8)
  final String? calculatedStatus; // 'upcoming' | 'live' | 'ended'
  
  @HiveField(9)
  final int totalAttendees;
  
  @HiveField(10)
  final int checkedInCount;
  
  @HiveField(11)
  final int vipCount;
  
  @HiveField(12)
  final String? regularBadgeTemplateId;
  
  @HiveField(13)
  final String? vipBadgeTemplateId;
  
  @HiveField(14)
  final DateTime createdAt;
  
  @HiveField(15)
  final DateTime updatedAt;

  Event({
    required this.id,
    this.eventbriteId,
    required this.name,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.venue,
    required this.status,
    this.calculatedStatus,
    required this.totalAttendees,
    required this.checkedInCount,
    required this.vipCount,
    this.regularBadgeTemplateId,
    this.vipBadgeTemplateId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      eventbriteId: json['eventbriteId'] as String?,
      name: json['name'] as String,
      description: json['description'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      venue: json['venue'] as String,
      status: json['status'] as String,
      calculatedStatus: json['calculatedStatus'] as String?,
      totalAttendees: int.tryParse(json['totalAttendees'].toString()) ?? 0,
      checkedInCount: int.tryParse(json['checkedInCount'].toString()) ?? 0,
      vipCount: int.tryParse(json['vipCount'].toString()) ?? 0,
      regularBadgeTemplateId: json['regularBadgeTemplateId'] as String?,
      vipBadgeTemplateId: json['vipBadgeTemplateId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventbriteId': eventbriteId,
      'name': name,
      'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'venue': venue,
      'status': status,
      'calculatedStatus': calculatedStatus,
      'totalAttendees': totalAttendees,
      'checkedInCount': checkedInCount,
      'vipCount': vipCount,
      'regularBadgeTemplateId': regularBadgeTemplateId,
      'vipBadgeTemplateId': vipBadgeTemplateId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Event copyWith({
    String? id,
    String? eventbriteId,
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? venue,
    String? status,
    String? calculatedStatus,
    int? totalAttendees,
    int? checkedInCount,
    int? vipCount,
    String? regularBadgeTemplateId,
    String? vipBadgeTemplateId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Event(
      id: id ?? this.id,
      eventbriteId: eventbriteId ?? this.eventbriteId,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      venue: venue ?? this.venue,
      status: status ?? this.status,
      calculatedStatus: calculatedStatus ?? this.calculatedStatus,
      totalAttendees: totalAttendees ?? this.totalAttendees,
      checkedInCount: checkedInCount ?? this.checkedInCount,
      vipCount: vipCount ?? this.vipCount,
      regularBadgeTemplateId: regularBadgeTemplateId ?? this.regularBadgeTemplateId,
      vipBadgeTemplateId: vipBadgeTemplateId ?? this.vipBadgeTemplateId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper method to get display status
  String get displayStatus {
    if (calculatedStatus != null) {
      return calculatedStatus!;
    }
    
    final now = DateTime.now();
    if (now.isBefore(startDate)) {
      return 'upcoming';
    } else if (now.isAfter(endDate)) {
      return 'ended';
    } else {
      return 'live';
    }
  }

  // Helper method to check if event is live
  bool get isLive => displayStatus == 'live';

  // Helper method to get check-in percentage
  double get checkInPercentage {
    if (totalAttendees == 0) return 0.0;
    return (checkedInCount / totalAttendees) * 100;
  }

  @override
  String toString() {
    return 'Event(id: $id, name: $name, status: $status, displayStatus: $displayStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Event && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}