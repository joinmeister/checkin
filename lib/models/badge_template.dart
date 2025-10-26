import 'dart:convert';
import 'package:hive/hive.dart';

part 'badge_template.g.dart';

@HiveType(typeId: 3)
class BadgeTemplate extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String eventId;

  @HiveField(3)
  final String labelSizeId;

  @HiveField(4)
  final bool isVipTemplate;

  @HiveField(5)
  final String backgroundColor;

  @HiveField(6)
  final String? backgroundImage;

  @HiveField(7)
  final Map<String, dynamic>? backgroundSettings;

  @HiveField(8)
  final String textColor;

  @HiveField(9)
  final String? logoUrl;

  @HiveField(10)
  final List<BadgeField> fields;

  @HiveField(11)
  final Map<String, dynamic> dimensions;

  @HiveField(12)
  final bool isDefault;

  @HiveField(13)
  final DateTime createdAt;

  @HiveField(14)
  final DateTime updatedAt;

  @HiveField(15)
  final bool isActive;

  BadgeTemplate({
    required this.id,
    required this.name,
    required this.eventId,
    required this.labelSizeId,
    required this.isVipTemplate,
    required this.backgroundColor,
    this.backgroundImage,
    this.backgroundSettings,
    required this.textColor,
    this.logoUrl,
    required this.fields,
    required this.dimensions,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
    required this.isActive,
  });

  factory BadgeTemplate.fromJson(Map<String, dynamic> json) {
    print('🔍 BADGE TEMPLATE: Parsing template ${json['id']}');
    print('🔍 BADGE TEMPLATE: Fields raw value: ${json['fields']}');
    print('🔍 BADGE TEMPLATE: Fields type: ${json['fields'].runtimeType}');
    
    // Parse fields - handle both string (JSON-encoded) and array formats
    List<BadgeField> fields = [];
    try {
      if (json['fields'] is String) {
        // Fields is a JSON string, decode it first
        print('🔍 BADGE TEMPLATE: Fields is JSON string, decoding...');
        final fieldsJson = jsonDecode(json['fields'] as String);
        if (fieldsJson is List) {
          fields = fieldsJson.map((field) => BadgeField.fromJson(field)).toList();
          print('✅ BADGE TEMPLATE: Successfully decoded ${fields.length} fields from JSON string');
        } else {
          print('❌ BADGE TEMPLATE: Decoded fields is not a List: ${fieldsJson.runtimeType}');
        }
      } else if (json['fields'] is List) {
        // Fields is already a List
        fields = (json['fields'] as List<dynamic>)
            .map((field) => BadgeField.fromJson(field))
            .toList();
        print('✅ BADGE TEMPLATE: Successfully parsed ${fields.length} fields from List');
      } else if (json['fields'] != null) {
        print('❌ BADGE TEMPLATE: Fields is neither String nor List: ${json['fields'].runtimeType}');
      } else {
        print('⚠️ BADGE TEMPLATE: Fields is null, using empty array');
      }
    } catch (e) {
      print('❌ BADGE TEMPLATE: Error parsing fields: $e');
      fields = [];
    }
    
    print('🔍 BADGE TEMPLATE: Final fields count: ${fields.length}');
    for (int i = 0; i < fields.length; i++) {
      final field = fields[i];
      print('  Field $i: ${field.type} - "${field.content}" at (${field.x}, ${field.y})');
    }
    
    return BadgeTemplate(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      eventId: json['eventId'] ?? '',
      labelSizeId: json['labelSizeId'] ?? '',
      isVipTemplate: json['isVipTemplate'] ?? false,
      backgroundColor: json['backgroundColor'] ?? '#FFFFFF',
      backgroundImage: json['backgroundImage'],
      backgroundSettings: json['backgroundSettings'] != null 
          ? Map<String, dynamic>.from(json['backgroundSettings']) 
          : null,
      textColor: json['textColor'] ?? '#000000',
      logoUrl: json['logoUrl'],
      fields: fields,
      dimensions: json['dimensions'] != null 
          ? Map<String, dynamic>.from(json['dimensions']) 
          : {'width': 400, 'height': 300},
      isDefault: json['isDefault'] ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'eventId': eventId,
      'labelSizeId': labelSizeId,
      'isVipTemplate': isVipTemplate,
      'backgroundColor': backgroundColor,
      'backgroundImage': backgroundImage,
      'backgroundSettings': backgroundSettings,
      'textColor': textColor,
      'logoUrl': logoUrl,
      'fields': fields.map((field) => field.toJson()).toList(),
      'dimensions': dimensions,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  BadgeTemplate copyWith({
    String? id,
    String? name,
    String? eventId,
    String? labelSizeId,
    bool? isVipTemplate,
    String? backgroundColor,
    String? backgroundImage,
    Map<String, dynamic>? backgroundSettings,
    String? textColor,
    String? logoUrl,
    List<BadgeField>? fields,
    Map<String, dynamic>? dimensions,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return BadgeTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      eventId: eventId ?? this.eventId,
      labelSizeId: labelSizeId ?? this.labelSizeId,
      isVipTemplate: isVipTemplate ?? this.isVipTemplate,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundImage: backgroundImage ?? this.backgroundImage,
      backgroundSettings: backgroundSettings ?? this.backgroundSettings,
      textColor: textColor ?? this.textColor,
      logoUrl: logoUrl ?? this.logoUrl,
      fields: fields ?? this.fields,
      dimensions: dimensions ?? this.dimensions,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  // Helper getters
  double get width => (dimensions['width'] ?? 400).toDouble();
  double get height => (dimensions['height'] ?? 300).toDouble();
  String get displaySize => '${width.toInt()} x ${height.toInt()}';
  
  bool get hasBackgroundImage => (backgroundImage != null && backgroundImage!.isNotEmpty) || (logoUrl != null && logoUrl!.isNotEmpty);
  
  String? get backgroundImageUrl => backgroundImage ?? logoUrl;
  
  List<BadgeField> get textFields => fields.where((field) => field.type == 'text').toList();
  
  List<BadgeField> get imageFields => fields.where((field) => field.type == 'image').toList();
  
  BadgeField? get nameField => fields.where((field) => field.content?.contains('{{firstName}}') == true || field.content?.contains('{{lastName}}') == true).firstOrNull;
  
  BadgeField? get emailField => fields.where((field) => field.content?.contains('{{email}}') == true).firstOrNull;
  
  BadgeField? get qrCodeField => fields.where((field) => field.type == 'qr').firstOrNull;
}

@HiveType(typeId: 4)
class BadgeField extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String type; // 'text', 'qr', 'logo', 'image'

  @HiveField(2)
  final String? content;

  @HiveField(3)
  final Map<String, double> position; // {x, y}

  @HiveField(4)
  final Map<String, double> size; // {width, height}

  @HiveField(5)
  final Map<String, dynamic> style; // {fontSize, fontWeight, color, textAlign}

  BadgeField({
    required this.id,
    required this.type,
    this.content,
    required this.position,
    required this.size,
    required this.style,
  });

  factory BadgeField.fromJson(Map<String, dynamic> json) {
    return BadgeField(
      id: json['id'] ?? '',
      type: json['type'] ?? 'text',
      content: json['content'],
      position: json['position'] != null 
          ? Map<String, double>.from(json['position'].map((k, v) => MapEntry(k, v.toDouble())))
          : {'x': 0.0, 'y': 0.0},
      size: json['size'] != null 
          ? Map<String, double>.from(json['size'].map((k, v) => MapEntry(k, v.toDouble())))
          : {'width': 100.0, 'height': 20.0},
      style: json['style'] != null 
          ? Map<String, dynamic>.from(json['style'])
          : {'fontSize': 12, 'fontWeight': 'normal', 'color': '#000000', 'textAlign': 'left'},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'content': content,
      'position': position,
      'size': size,
      'style': style,
    };
  }

  BadgeField copyWith({
    String? id,
    String? type,
    String? content,
    Map<String, double>? position,
    Map<String, double>? size,
    Map<String, dynamic>? style,
  }) {
    return BadgeField(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      position: position ?? this.position,
      size: size ?? this.size,
      style: style ?? this.style,
    );
  }

  // Helper getters
  bool get isTextField => type == 'text';
  bool get isImageField => type == 'image';
  bool get isQrField => type == 'qr';
  bool get isLogoField => type == 'logo';
  
  double get x => position['x'] ?? 0.0;
  double get y => position['y'] ?? 0.0;
  double get width => size['width'] ?? 100.0;
  double get height => size['height'] ?? 20.0;
  
  double get fontSize => (style['fontSize'] ?? 12).toDouble();
  String get fontWeight => style['fontWeight'] ?? 'normal';
  String get color => style['color'] ?? '#000000';
  String get textAlign => style['textAlign'] ?? 'left';
  
  String get displayPosition => '(${x.toInt()}, ${y.toInt()})';
  String get displaySize => '${width.toInt()} x ${height.toInt()}';
}