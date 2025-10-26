import 'package:flutter/foundation.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class EventProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<Event> _events = [];
  Event? _selectedEvent;
  bool _isLoading = false;
  String? _error;
  String _searchTerm = '';
  String _statusFilter = 'all';
  DateTime? _lastRefresh;

  // Getters
  List<Event> get events => _events;
  Event? get selectedEvent => _selectedEvent;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchTerm => _searchTerm;
  String get statusFilter => _statusFilter;
  DateTime? get lastRefresh => _lastRefresh;

  // Filtered and sorted events
  List<Event> get filteredEvents {
    List<Event> filtered = _events;

    // Apply search filter
    if (_searchTerm.isNotEmpty) {
      filtered = filtered.where((event) {
        final searchLower = _searchTerm.toLowerCase();
        return event.name.toLowerCase().contains(searchLower) ||
               event.venue.toLowerCase().contains(searchLower) ||
               event.description.toLowerCase().contains(searchLower);
      }).toList();
    }

    // Apply status filter
    if (_statusFilter != 'all') {
      filtered = filtered.where((event) {
        return event.displayStatus == _statusFilter;
      }).toList();
    }

    // Sort events: live first, then by start date (newest first)
    filtered.sort((a, b) {
      // Live events always on top
      if (a.isLive && !b.isLive) return -1;
      if (b.isLive && !a.isLive) return 1;
      
      // Then by start date (newest first for current events)
      return b.startDate.compareTo(a.startDate);
    });

    return filtered;
  }

  // Live events count
  int get liveEventsCount {
    return _events.where((event) => event.isLive).length;
  }

  // Total attendees across all events
  int get totalAttendees {
    return _events.fold(0, (sum, event) => sum + event.totalAttendees);
  }

  // Total checked-in attendees across all events
  int get totalCheckedIn {
    return _events.fold(0, (sum, event) => sum + event.checkedInCount);
  }

  // Load events from API
  Future<void> loadEvents({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    print('🔄 EventProvider: Starting to load events (forceRefresh: $forceRefresh)');
    _setLoading(true);
    _setError(null);

    try {
      print('🔄 EventProvider: Calling API service to get events');
      final events = await _apiService.getEvents();
      
      print('📊 EventProvider: Received ${events.length} events from API');
      
      if (events.isNotEmpty) {
        print('📊 EventProvider: First event details:');
        print('  - ID: ${events.first.id}');
        print('  - Name: ${events.first.name}');
        print('  - Status: ${events.first.status}');
        print('  - Display Status: ${events.first.displayStatus}');
        print('  - Start Date: ${events.first.startDate}');
        print('  - End Date: ${events.first.endDate}');
        print('  - Venue: ${events.first.venue}');
        print('  - Total Attendees: ${events.first.totalAttendees}');
      } else {
        print('⚠️ EventProvider: No events received from API');
      }
      
      _events = events;
      _lastRefresh = DateTime.now();
      
      print('📊 EventProvider: Updated _events list with ${_events.length} events');
      
      // Update selected event if it exists in the new list
      if (_selectedEvent != null) {
        print('🔄 EventProvider: Updating selected event');
        final updatedEvent = _events.firstWhere(
          (event) => event.id == _selectedEvent!.id,
          orElse: () => _selectedEvent!,
        );
        _selectedEvent = updatedEvent;
        print('✅ EventProvider: Selected event updated');
      }
      
      print('📊 EventProvider: Notifying listeners');
      notifyListeners();
      print('✅ EventProvider: Events loaded successfully');
    } catch (e) {
      print('❌ EventProvider: Error loading events: $e');
      _setError('Failed to load events: ${e.toString()}');
    } finally {
      _setLoading(false);
      print('🔄 EventProvider: Loading completed');
    }
  }

  // Refresh events
  Future<void> refreshEvents() async {
    await loadEvents(forceRefresh: true);
  }

  // Select an event
  void selectEvent(Event event) {
    _selectedEvent = event;
    notifyListeners();
  }

  // Select event by ID
  Future<void> selectEventById(String eventId) async {
    // First try to find in current events list
    final event = _events.firstWhere(
      (event) => event.id == eventId,
      orElse: () => Event(
        id: '',
        name: '',
        description: '',
        startDate: DateTime.now(),
        endDate: DateTime.now(),
        venue: '',
        status: 'draft',
        totalAttendees: 0,
        checkedInCount: 0,
        vipCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    if (event.id.isNotEmpty) {
      selectEvent(event);
      return;
    }

    // If not found, try to fetch from API
    try {
      final fetchedEvent = await _apiService.getEvent(eventId);
      if (fetchedEvent != null) {
        selectEvent(fetchedEvent);
        // Also add to events list if not already there
        if (!_events.any((e) => e.id == eventId)) {
          _events.add(fetchedEvent);
          notifyListeners();
        }
      }
    } catch (e) {
      _setError('Failed to load event: ${e.toString()}');
    }
  }

  // Clear selected event
  void clearSelectedEvent() {
    _selectedEvent = null;
    notifyListeners();
  }

  // Update search term
  void updateSearchTerm(String term) {
    _searchTerm = term;
    notifyListeners();
  }

  // Update status filter
  void updateStatusFilter(String filter) {
    _statusFilter = filter;
    notifyListeners();
  }

  // Clear filters
  void clearFilters() {
    _searchTerm = '';
    _statusFilter = 'all';
    notifyListeners();
  }

  // Get event by ID
  Event? getEventById(String eventId) {
    try {
      return _events.firstWhere((event) => event.id == eventId);
    } catch (e) {
      return null;
    }
  }

  // Update event in the list (after check-in updates)
  void updateEvent(Event updatedEvent) {
    final index = _events.indexWhere((event) => event.id == updatedEvent.id);
    if (index != -1) {
      _events[index] = updatedEvent;
      
      // Update selected event if it's the same
      if (_selectedEvent?.id == updatedEvent.id) {
        _selectedEvent = updatedEvent;
      }
      
      notifyListeners();
    }
  }

  // Check if events need refresh (older than 5 minutes)
  bool get needsRefresh {
    if (_lastRefresh == null) return true;
    final now = DateTime.now();
    return now.difference(_lastRefresh!).inMinutes > 5;
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Legacy method aliases for compatibility
  Future<void> fetchEvents() async {
    await loadEvents();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}