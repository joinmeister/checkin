import 'package:hive/hive.dart';

part 'attendee.g.dart';

@HiveType(typeId: 1)
class Attendee {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String eventId;
  
  @HiveField(2)
  final String? eventbriteId;
  
  @HiveField(3)
  final String firstName;
  
  @HiveField(4)
  final String lastName;
  
  @HiveField(5)
  final String email;
  
  @HiveField(6)
  final String ticketType;
  
  @HiveField(7)
  final double? ticketPrice;
  
  @HiveField(8)
  final bool isVip;
  
  @HiveField(9)
  final bool isCheckedIn;
  
  @HiveField(10)
  final DateTime? checkedInAt;
  
  @HiveField(11)
  final String qrCode;
  
  @HiveField(12)
  final bool badgeGenerated;
  
  @HiveField(13)
  final String? vipLogoUrl;
  
  @HiveField(14)
  final DateTime createdAt;
  
  @HiveField(15)
  final DateTime updatedAt;

  Attendee({
    required this.id,
    required this.eventId,
    this.eventbriteId,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.ticketType,
    this.ticketPrice,
    required this.isVip,
    required this.isCheckedIn,
    this.checkedInAt,
    required this.qrCode,
    required this.badgeGenerated,
    this.vipLogoUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Attendee.fromJson(Map<String, dynamic> json) {
    return Attendee(
      id: json['id'] as String,
      eventId: json['eventId'] as String,
      eventbriteId: json['eventbriteId'] as String?,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      email: json['email'] as String,
      ticketType: json['ticketType'] as String,
      ticketPrice: json['ticketPrice'] != null 
          ? (json['ticketPrice'] is String 
              ? double.tryParse(json['ticketPrice']) 
              : json['ticketPrice']?.toDouble())
          : null,
      isVip: json['isVip'] as bool,
      isCheckedIn: json['isCheckedIn'] as bool,
      checkedInAt: json['checkedInAt'] != null 
          ? DateTime.parse(json['checkedInAt'] as String)
          : null,
      qrCode: json['qrCode'] as String,
      badgeGenerated: json['badgeGenerated'] as bool,
      vipLogoUrl: json['vipLogoUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventId': eventId,
      'eventbriteId': eventbriteId,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'ticketType': ticketType,
      'ticketPrice': ticketPrice,
      'isVip': isVip,
      'isCheckedIn': isCheckedIn,
      'checkedInAt': checkedInAt?.toIso8601String(),
      'qrCode': qrCode,
      'badgeGenerated': badgeGenerated,
      'vipLogoUrl': vipLogoUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Attendee copyWith({
    String? id,
    String? eventId,
    String? eventbriteId,
    String? firstName,
    String? lastName,
    String? email,
    String? ticketType,
    double? ticketPrice,
    bool? isVip,
    bool? isCheckedIn,
    DateTime? checkedInAt,
    String? qrCode,
    bool? badgeGenerated,
    String? vipLogoUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Attendee(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      eventbriteId: eventbriteId ?? this.eventbriteId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      ticketType: ticketType ?? this.ticketType,
      ticketPrice: ticketPrice ?? this.ticketPrice,
      isVip: isVip ?? this.isVip,
      isCheckedIn: isCheckedIn ?? this.isCheckedIn,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      qrCode: qrCode ?? this.qrCode,
      badgeGenerated: badgeGenerated ?? this.badgeGenerated,
      vipLogoUrl: vipLogoUrl ?? this.vipLogoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Helper method to get full name
  String get fullName => '$firstName $lastName';

  // Helper method to get display name (for UI)
  String get displayName {
    final name = fullName.trim();
    return name.isEmpty ? email : name;
  }

  // Helper method to check if attendee was checked in today
  bool get isCheckedInToday {
    if (!isCheckedIn || checkedInAt == null) return false;
    
    final now = DateTime.now();
    final checkInDate = checkedInAt!;
    
    return now.year == checkInDate.year &&
           now.month == checkInDate.month &&
           now.day == checkInDate.day;
  }

  // Helper method to get check-in time formatted
  String? get formattedCheckInTime {
    if (checkedInAt == null) return null;
    
    final time = checkedInAt!;
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    return 'Attendee(id: $id, name: $fullName, email: $email, isVip: $isVip, isCheckedIn: $isCheckedIn)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Attendee && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}