import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/event.dart';
import '../models/attendee.dart';
import '../utils/constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final String _baseUrl = AppConstants.baseUrl;
  final Duration _timeout = Duration(milliseconds: AppConstants.apiTimeout);

  // HTTP client with timeout
  http.Client get _client => http.Client();

  // Helper method to build headers
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Test API connectivity
  Future<bool> testConnection() async {
    try {
      print('🌐 API: Testing connection to $_baseUrl');
      final response = await _client.get(
        Uri.parse('$_baseUrl/events'),
        headers: _headers,
      ).timeout(Duration(seconds: 10));
      
      print('🌐 API: Connection test response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ API: Connection test failed: $e');
      return false;
    }
  }

  // Helper method to handle HTTP requests
  Future<dynamic> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint').replace(
        queryParameters: queryParams,
      );

      print('🌐 HTTP: Making $method request to: $uri');
      print('🌐 HTTP: Base URL: $_baseUrl');
      print('🌐 HTTP: Endpoint: $endpoint');

      http.Response response;
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _client.get(uri, headers: _headers).timeout(_timeout);
          break;
        case 'POST':
          response = await _client.post(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(_timeout);
          break;
        case 'PUT':
          response = await _client.put(
            uri,
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(_timeout);
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: _headers).timeout(_timeout);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      print('🌐 HTTP: Response status: ${response.statusCode}');
      print('🌐 HTTP: Response headers: ${response.headers}');
      print('🌐 HTTP: Response body length: ${response.body.length}');
      print('🌐 HTTP: Response body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          print('🌐 HTTP: Empty response body, returning success');
          return {'success': true};
        }
        final decoded = jsonDecode(response.body);
        print('🌐 HTTP: Decoded response type: ${decoded.runtimeType}');
        return decoded;
      } else {
        print('❌ HTTP: Error response ${response.statusCode}: ${response.reasonPhrase}');
        throw HttpException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          uri: uri,
        );
      }
    } catch (e) {
      print('❌ HTTP: Request failed for $endpoint: $e');
      rethrow;
    }
  }

  // Events API
  Future<List<Event>> getEvents() async {
    try {
      print('🔍 API: Fetching events from ${AppConstants.eventsEndpoint}');
      final response = await _makeRequest('GET', AppConstants.eventsEndpoint);
      
      print('📡 API: Raw response type: ${response.runtimeType}');
      print('📡 API: Raw response: $response');
      
      // Handle direct array response (like main web app)
      if (response is List) {
        print('📡 API: Response is List with ${response.length} items');
        final events = <Event>[];
        
        for (int i = 0; i < response.length; i++) {
          try {
            print('📡 API: Parsing event $i: ${response[i]}');
            final event = Event.fromJson(response[i] as Map<String, dynamic>);
            events.add(event);
            print('✅ API: Successfully parsed event: ${event.name} (${event.id})');
          } catch (e) {
            print('❌ API: Failed to parse event $i: $e');
            print('❌ API: Event data: ${response[i]}');
          }
        }
        
        print('📡 API: Successfully parsed ${events.length} events');
        return events;
      }
      
      // Fallback for wrapped response format
      if (response is Map<String, dynamic> && response['data'] is List) {
        print('📡 API: Response is wrapped Map with data field');
        final dataList = response['data'] as List;
        print('📡 API: Data list has ${dataList.length} items');
        
        final events = <Event>[];
        for (int i = 0; i < dataList.length; i++) {
          try {
            print('📡 API: Parsing wrapped event $i: ${dataList[i]}');
            final event = Event.fromJson(dataList[i] as Map<String, dynamic>);
            events.add(event);
            print('✅ API: Successfully parsed wrapped event: ${event.name} (${event.id})');
          } catch (e) {
            print('❌ API: Failed to parse wrapped event $i: $e');
            print('❌ API: Event data: ${dataList[i]}');
          }
        }
        
        print('📡 API: Successfully parsed ${events.length} wrapped events');
        return events;
      }
      
      print('⚠️ API: Unexpected response format, returning empty list');
      return [];
    } catch (e) {
      print('❌ API: Error fetching events: $e');
      return [];
    }
  }

  Future<Event?> getEvent(String eventId) async {
    try {
      final response = await _makeRequest('GET', '${AppConstants.eventsEndpoint}/$eventId');
      
      // Handle direct object response (like main web app)
      if (response is Map<String, dynamic>) {
        return Event.fromJson(response);
      }
      // Fallback for wrapped response format
      if (response['data'] != null) {
        return Event.fromJson(response['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error fetching event $eventId: $e');
      return null;
    }
  }

  // Attendees API
  Future<List<Attendee>> getAttendees({String? eventId}) async {
    try {
      // Use path parameter instead of query parameter for event filtering
      final endpoint = eventId != null 
          ? '${AppConstants.attendeesEndpoint}/$eventId'
          : AppConstants.attendeesEndpoint;
      
      final response = await _makeRequest('GET', endpoint);
      
      // Handle direct array response (like main web app)
      if (response is List) {
        return response
            .map((json) => Attendee.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      // Fallback for wrapped response format
      if (response['data'] is List) {
        return (response['data'] as List)
            .map((json) => Attendee.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching attendees: $e');
      return [];
    }
  }

  Future<Attendee?> getAttendee(String attendeeId) async {
    try {
      final response = await _makeRequest('GET', '${AppConstants.attendeesEndpoint}/$attendeeId');
      
      // Handle direct object response (like main web app)
      if (response is Map<String, dynamic>) {
        return Attendee.fromJson(response);
      }
      // Fallback for wrapped response format
      if (response['data'] != null) {
        return Attendee.fromJson(response['data'] as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error fetching attendee $attendeeId: $e');
      return null;
    }
  }

  // Check-in API
  Future<Map<String, dynamic>> checkInAttendee(String attendeeId) async {
    try {
      final response = await _makeRequest(
        'POST',
        '${AppConstants.attendeesEndpoint}/$attendeeId/checkin',
      );
      return response is Map<String, dynamic> ? response : {'success': true};
    } catch (e) {
      print('Error checking in attendee $attendeeId: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> checkInAttendeeByQR(String qrCode) async {
    try {
      final response = await _makeRequest(
        'POST',
        AppConstants.checkInEndpoint,
        body: {'qrCode': qrCode},
      );
      return response is Map<String, dynamic> ? response : {'success': true};
    } catch (e) {
      print('Error checking in by QR $qrCode: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> checkInAttendeeById(String eventId, String attendeeId) async {
    try {
      // Get attendees for the event to find the specific attendee
      final attendees = await getAttendees(eventId: eventId);
      
      // Find the attendee by ID
      final attendee = attendees.firstWhere(
        (a) => a.id == attendeeId,
        orElse: () => throw Exception('Attendee not found'),
      );
      
      // Use the same QR check-in endpoint as the web app
      final response = await _makeRequest(
        'POST',
        AppConstants.checkInEndpoint,
        body: {'qrCode': attendee.qrCode},
      );
      
      // Ensure we return the expected format with attendee data
      if (response is Map<String, dynamic> && response['success'] == true) {
        // The QR check-in endpoint returns attendee data, so we can use it directly
        return response;
      } else {
        // Fallback: manually update the attendee and return success
        final updatedAttendee = attendee.copyWith(
          isCheckedIn: true,
          checkedInAt: DateTime.now(),
        );
        
        return {
          'success': true,
          'attendee': updatedAttendee.toJson(),
          'message': 'Checked in successfully'
        };
      }
    } catch (e) {
      print('Error checking in attendee $attendeeId: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uncheckAttendee(String attendeeId) async {
    try {
      final response = await _makeRequest(
        'POST',
        '${AppConstants.attendeesEndpoint}/$attendeeId/uncheck',
      );
      return response is Map<String, dynamic> ? response : {'success': true};
    } catch (e) {
      print('Error unchecking attendee $attendeeId: $e');
      rethrow;
    }
  }

  // Walk-in registration API
  Future<Map<String, dynamic>> addWalkInAttendee({
    required String eventId,
    required String firstName,
    required String lastName,
    required String email,
    String ticketType = 'Walk-in',
    bool isVip = false,
  }) async {
    try {
      final response = await _makeRequest(
        'POST',
        AppConstants.walkInEndpoint,
        body: {
          'eventId': eventId,
          'firstName': firstName,
          'lastName': lastName,
          'email': email,
          'ticketType': ticketType,
          'isVip': isVip,
        },
      );
      return response is Map<String, dynamic> ? response : {'success': true};
    } catch (e) {
      print('Error adding walk-in attendee: $e');
      rethrow;
    }
  }

  // Alias for sync service compatibility
  Future<Map<String, dynamic>> addWalkIn({
    required String eventId,
    required String firstName,
    required String lastName,
    required String email,
    String ticketType = 'Walk-in',
    bool isVip = false,
  }) async {
    return addWalkInAttendee(
      eventId: eventId,
      firstName: firstName,
      lastName: lastName,
      email: email,
      ticketType: ticketType,
      isVip: isVip,
    );
  }

  // Badge Templates API
  Future<List<Map<String, dynamic>>> getBadgeTemplates({String? eventId}) async {
    try {
      // CRITICAL FIX: Load ALL templates by default (like web app)
      // Only filter by eventId if explicitly requested
      final queryParams = eventId != null ? {'eventId': eventId} : null;
      final response = await _makeRequest(
        'GET',
        AppConstants.badgeTemplatesEndpoint,
        queryParams: queryParams,
      );
      
      print('🔍 BADGE TEMPLATES: Raw API response type: ${response.runtimeType}');
      print('🔍 BADGE TEMPLATES: Raw API response: $response');
      
      List<Map<String, dynamic>> templates = [];
      
      // Handle direct array response (like main web app)
      if (response is List) {
        templates = response.cast<Map<String, dynamic>>();
      }
      // Fallback for wrapped response format
      else if (response is Map<String, dynamic> && response['data'] is List) {
        templates = List<Map<String, dynamic>>.from(response['data']);
      }
      
      // Log detailed template information
      print('🔍 BADGE TEMPLATES: Found ${templates.length} templates');
      for (int i = 0; i < templates.length; i++) {
        final template = templates[i];
        print('🔍 BADGE TEMPLATES: Template $i:');
        print('  - ID: ${template['id']}');
        print('  - Name: ${template['name']}');
        print('  - EventId: ${template['eventId']}');
        print('  - IsVipTemplate: ${template['isVipTemplate']}');
        print('  - BackgroundColor: ${template['backgroundColor']}');
        print('  - LogoUrl: ${template['logoUrl']}');
        print('  - Dimensions: ${template['dimensions']}');
        print('  - Fields type: ${template['fields'].runtimeType}');
        print('  - Fields content: ${template['fields']}');
        
        // Check if fields is a string that needs JSON decoding
        if (template['fields'] is String) {
          print('⚠️ BADGE TEMPLATES: Fields is a JSON string, needs decoding');
        } else if (template['fields'] is List) {
          print('✅ BADGE TEMPLATES: Fields is a List with ${(template['fields'] as List).length} items');
        } else {
          print('❌ BADGE TEMPLATES: Fields is neither String nor List: ${template['fields']}');
        }
      }
      
      return templates;
    } catch (e) {
      print('❌ BADGE TEMPLATES: Error fetching badge templates: $e');
      return [];
    }
  }

  // Analytics and Timing API
  Future<void> recordCheckInTiming({
    required String attendeeId,
    required String eventId,
    required String checkinType,
    required DateTime processStartTime,
    required DateTime processEndTime,
    int? scanDurationSeconds,
    int? printDurationSeconds,
    int? registrationDurationSeconds,
  }) async {
    try {
      final totalDurationSeconds = processEndTime.difference(processStartTime).inSeconds;
      
      await _makeRequest(
        'POST',
        AppConstants.timingEndpoint,
        body: {
          'attendeeId': attendeeId,
          'eventId': eventId,
          'checkinType': checkinType,
          'processStartTime': processStartTime.toIso8601String(),
          'processEndTime': processEndTime.toIso8601String(),
          'totalDurationSeconds': totalDurationSeconds,
          'scanDurationSeconds': scanDurationSeconds,
          'printDurationSeconds': printDurationSeconds,
          'registrationDurationSeconds': registrationDurationSeconds,
        },
      );
    } catch (e) {
      print('Error recording check-in timing: $e');
      // Don't rethrow for timing data - it's not critical
    }
  }

  // Print badge for attendee
  Future<Map<String, dynamic>> printBadge(String attendeeId) async {
    try {
      // Since the backend doesn't have a print endpoint, we'll simulate success
      // The actual printing is handled client-side through the BadgeProvider
      print('Print badge request for attendee: $attendeeId');
      return {'success': true, 'message': 'Badge print request processed'};
    } catch (e) {
      print('Error printing badge: $e');
      return {'success': false, 'error': 'Failed to process print request'};
    }
  }



  // Sync operations
  Future<Map<String, dynamic>> triggerSync() async {
    try {
      final response = await _makeRequest('POST', '/sync');
      return response is Map<String, dynamic> ? response : {'success': true};
    } catch (e) {
      print('Error triggering sync: $e');
      rethrow;
    }
  }

  // Dispose method to clean up resources
  void dispose() {
    _client.close();
  }
}