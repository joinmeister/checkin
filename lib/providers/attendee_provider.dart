import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/attendee.dart';
import '../models/event.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue_service.dart';
import '../services/sync_service.dart';
import '../services/attendee_cache_service.dart';
import '../utils/constants.dart';

class AttendeeProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final ConnectivityService _connectivityService = ConnectivityService();
  final OfflineQueueService _queueService = OfflineQueueService();
  final AttendeeCacheService _cacheService = AttendeeCacheService();
  
  // SyncService will be injected from Provider
  SyncService? _syncService;
  
  // Make queue service accessible for offline queue dialog
  OfflineQueueService get queueService => _queueService;
  
  List<Attendee> _attendees = [];
  bool _isLoading = false;
  String? _error;
  String _searchTerm = '';
  String _statusFilter = 'all'; // all, checked-in, not-checked-in, vip
  String? _currentEventId;
  DateTime? _lastRefresh;
  
  // Check-in related state
  bool _isCheckingIn = false;
  String? _checkInError;
  String? _lastScannedQR;
  
  // Walk-in related state
  Attendee? _lastCreatedAttendee;
  
  // Offline support state
  bool _isOffline = false;
  int _queuedActionsCount = 0;
  Timer? _queueCountRefreshTimer;

  // Getters
  List<Attendee> get attendees => _attendees;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchTerm => _searchTerm;
  String get statusFilter => _statusFilter;
  String? get currentEventId => _currentEventId;
  DateTime? get lastRefresh => _lastRefresh;
  bool get isCheckingIn => _isCheckingIn;
  String? get checkInError => _checkInError;
  String? get lastScannedQR => _lastScannedQR;
  Attendee? get lastCreatedAttendee => _lastCreatedAttendee;
  
  // Offline support getters
  bool get isOffline => _isOffline;
  int get queuedActionsCount => _queuedActionsCount;
  bool get hasQueuedActions => _queuedActionsCount > 0;

  // Filtered and sorted attendees
  List<Attendee> get filteredAttendees {
    List<Attendee> filtered = _attendees;

    // Apply search filter
    if (_searchTerm.isNotEmpty) {
      filtered = filtered.where((attendee) {
        final searchLower = _searchTerm.toLowerCase();
        return attendee.fullName.toLowerCase().contains(searchLower) ||
               attendee.email.toLowerCase().contains(searchLower) ||
               attendee.ticketType.toLowerCase().contains(searchLower);
      }).toList();
    }

    // Apply status filter
    switch (_statusFilter) {
      case 'checked-in':
        filtered = filtered.where((attendee) => attendee.isCheckedIn).toList();
        break;
      case 'not-checked-in':
        filtered = filtered.where((attendee) => !attendee.isCheckedIn).toList();
        break;
      case 'vip':
        filtered = filtered.where((attendee) => attendee.isVip).toList();
        break;
      case 'all':
      default:
        // No additional filtering
        break;
    }

    // Sort attendees: VIPs first, then by check-in status, then alphabetically
    filtered.sort((a, b) {
      // VIPs first
      if (a.isVip && !b.isVip) return -1;
      if (b.isVip && !a.isVip) return 1;
      
      // Then by check-in status (checked-in first)
      if (a.isCheckedIn && !b.isCheckedIn) return -1;
      if (b.isCheckedIn && !a.isCheckedIn) return 1;
      
      // Finally alphabetically by full name
      return a.fullName.compareTo(b.fullName);
    });

    return filtered;
  }

  // Statistics
  int get totalAttendees => _attendees.length;
  int get checkedInCount => _attendees.where((a) => a.isCheckedIn).length;
  int get vipCount => _attendees.where((a) => a.isVip).length;
  int get notCheckedInCount => _attendees.where((a) => !a.isCheckedIn).length;
  
  double get checkInPercentage {
    if (totalAttendees == 0) return 0.0;
    return (checkedInCount / totalAttendees) * 100;
  }

  // Load attendees for a specific event
  Future<void> loadAttendees(String eventId, {bool forceRefresh = false, bool loadFromCacheFirst = true}) async {
    if (_isLoading && !forceRefresh) return;
    if (_currentEventId == eventId && !forceRefresh && !needsRefresh) return;

    _setLoading(true);
    _setError(null);
    _currentEventId = eventId;

    try {
      // Load from cache first for instant UI
      if (loadFromCacheFirst && !forceRefresh) {
        final cachedAttendees = await _cacheService.getCachedAttendees(eventId);
        if (cachedAttendees != null) {
          _attendees = cachedAttendees;
          _lastRefresh = await _cacheService.getCacheTimestamp(eventId);
          print('✅ PROVIDER: Loaded ${_attendees.length} attendees from cache');
          notifyListeners();
          
          // Check if cache is stale
          final isStale = await _cacheService.isCacheStale(eventId);
          if (!isStale && !forceRefresh) {
            _setLoading(false);
            return; // Cache is fresh, no need to fetch
          }
        }
      }

      // Fetch fresh data from API
      if (_connectivityService.isOnline) {
        print('🌐 PROVIDER: Fetching fresh attendees from API');
        final attendees = await _apiService.getAttendees(eventId: eventId);
        _attendees = attendees;
        _lastRefresh = DateTime.now();
        
        // Cache the fresh data
        await _cacheService.cacheAttendees(eventId, attendees);
        print('✅ PROVIDER: Cached ${attendees.length} attendees');
        
        notifyListeners();
      } else {
        // Offline and no cache available
        if (_attendees.isEmpty) {
          _setError('No internet connection and no cached data available');
        }
      }
    } catch (e) {
      _setError('Failed to load attendees: ${e.toString()}');
      print('❌ PROVIDER: Error loading attendees: $e');
    } finally {
      _setLoading(false);
    }
  }
  
  // Load cached attendees only (for app restart scenarios)
  Future<void> loadCachedAttendees(String eventId) async {
    try {
      final cachedAttendees = await _cacheService.getCachedAttendees(eventId);
      if (cachedAttendees != null) {
        _attendees = cachedAttendees;
        _currentEventId = eventId;
        _lastRefresh = await _cacheService.getCacheTimestamp(eventId);
        
        // Count checked-in attendees in cache
        final checkedInCount = cachedAttendees.where((a) => a.isCheckedIn).length;
        print('✅ PROVIDER: Restored ${_attendees.length} attendees from cache on app restart');
        print('   - Checked-in attendees: $checkedInCount');
        print('   - Cache timestamp: $_lastRefresh');
        
        notifyListeners();
      } else {
        print('ℹ️ PROVIDER: No cached attendees found for event $eventId');
      }
    } catch (e) {
      print('❌ PROVIDER: Error loading cached attendees: $e');
    }
  }

  // Refresh attendees for current event
  Future<void> refreshAttendees() async {
    if (_currentEventId != null) {
      await loadAttendees(_currentEventId!, forceRefresh: true, loadFromCacheFirst: false);
    }
  }
  
  // Silent refresh (no loading state, used after sync)
  Future<void> silentRefreshAttendees() async {
    if (_currentEventId != null && _connectivityService.isOnline) {
      try {
        print('🔄 PROVIDER: Silent refresh started');
        final attendees = await _apiService.getAttendees(eventId: _currentEventId!);
        _attendees = attendees;
        _lastRefresh = DateTime.now();
        
        // Cache the fresh data
        await _cacheService.cacheAttendees(_currentEventId!, attendees);
        print('✅ PROVIDER: Silent refresh completed with ${attendees.length} attendees');
        
        notifyListeners();
      } catch (e) {
        print('❌ PROVIDER: Silent refresh failed: $e');
        // Don't show error to user for silent refresh
      }
    }
  }

  // Check in attendee by QR code
  Future<bool> checkInByQR(String qrCode) async {
    if (_currentEventId == null) {
      _setCheckInError('No event selected');
      return false;
    }

    _setCheckingIn(true);
    _setCheckInError(null);
    _lastScannedQR = qrCode;

    try {
      // Check if we're online
      if (_connectivityService.isOnline) {
        final result = await _apiService.checkInAttendeeByQR(qrCode);
        
        if (result['success'] == true) {
          // Update the attendee in the local list
          final attendeeData = result['attendee'];
          if (attendeeData != null) {
            final updatedAttendee = Attendee.fromJson(attendeeData);
            _updateAttendeeInList(updatedAttendee);
            
            // Update cache
            if (_currentEventId != null) {
              await _cacheService.updateAttendeeInCache(_currentEventId!, updatedAttendee);
            }
          }
          
          // Clear any previous errors
          _setCheckInError(null);
          return true;
        } else {
          _setCheckInError(result['message'] ?? 'Check-in failed');
          return false;
        }
      } else {
        // We're offline, queue the action
        await _queueService.queueCheckInByQR(
          eventId: _currentEventId!,
          qrCode: qrCode,
          timestamp: DateTime.now(),
        );
        
        // Optimistically update UI (find attendee by QR and mark as checked in)
        final attendee = _attendees.firstWhere(
          (a) => a.qrCode == qrCode,
          orElse: () => _attendees.first, // Fallback, shouldn't happen
        );
        if (attendee.qrCode == qrCode) {
          final updatedAttendee = attendee.copyWith(
            isCheckedIn: true,
            checkedInAt: DateTime.now(),
          );
          _updateAttendeeInList(updatedAttendee);
          
          // Update cache with optimistic update
          if (_currentEventId != null) {
            await _cacheService.updateAttendeeInCache(_currentEventId!, updatedAttendee);
            print('💾 PROVIDER: Cached optimistic QR check-in for ${updatedAttendee.fullName}');
          }
        }
        
        _updateQueuedActionsCount();
        _setCheckInError(null);
        return true; // Return true for offline queuing
      }
    } catch (e) {
      // If online request fails, try to queue it offline
      if (_connectivityService.isOnline) {
        _setCheckInError('Check-in failed: ${e.toString()}');
        return false;
      } else {
        // Queue the action for later sync
        await _queueService.queueCheckInByQR(
          eventId: _currentEventId!,
          qrCode: qrCode,
          timestamp: DateTime.now(),
        );
        
        _updateQueuedActionsCount();
        _setCheckInError(null);
        return true;
      }
    } finally {
      _setCheckingIn(false);
    }
  }

  // Check-in result data
  bool _wasAlreadyCheckedIn = false;
  bool get wasAlreadyCheckedIn => _wasAlreadyCheckedIn;
  
  // Check in attendee by ID
  Future<bool> checkInAttendeeById(String attendeeId) async {
    print('🔍 PROVIDER: Starting checkInAttendeeById for $attendeeId');
    
    if (_currentEventId == null) {
      _setCheckInError('No event selected');
      print('🔍 PROVIDER: No event selected');
      return false;
    }

    _setCheckingIn(true);
    _setCheckInError(null);
    _wasAlreadyCheckedIn = false; // Reset flag

    try {
      // Check if we're online
      if (_connectivityService.isOnline) {
        print('🔍 PROVIDER: Online, calling API service');
        final result = await _apiService.checkInAttendeeById(_currentEventId!, attendeeId);
        print('🔍 PROVIDER: API service returned: $result');
        
        if (result['success'] == true) {
          // Check if attendee was already checked in
          _wasAlreadyCheckedIn = result['alreadyCheckedIn'] == true;
          print('🔍 PROVIDER: Was already checked in: $_wasAlreadyCheckedIn');
          
          // Update the attendee in the local list
          final attendeeData = result['attendee'];
          if (attendeeData != null) {
            print('🔍 PROVIDER: Updating attendee in list with data: $attendeeData');
            final updatedAttendee = Attendee.fromJson(attendeeData);
            _updateAttendeeInList(updatedAttendee);
            
            // Update cache
            if (_currentEventId != null) {
              await _cacheService.updateAttendeeInCache(_currentEventId!, updatedAttendee);
            }
            
            print('🔍 PROVIDER: Attendee updated in list and cache');
          } else {
            print('🔍 PROVIDER: No attendee data in response');
          }
          
          _setCheckInError(null);
          print('🔍 PROVIDER: Returning success');
          return true;
        } else {
          _setCheckInError(result['message'] ?? 'Check-in failed');
          print('🔍 PROVIDER: Check-in failed: ${result['message']}');
          return false;
        }
      } else {
        print('🔍 PROVIDER: Offline, queuing action');
        // We're offline, queue the action
        await _queueService.queueCheckInById(
          eventId: _currentEventId!,
          attendeeId: attendeeId,
          timestamp: DateTime.now(),
        );
        
        // Optimistically update the UI for offline mode
        final index = _attendees.indexWhere((a) => a.id == attendeeId);
        if (index != -1) {
          final updatedAttendee = _attendees[index].copyWith(
            isCheckedIn: true,
            checkedInAt: DateTime.now(),
          );
          _updateAttendeeInList(updatedAttendee);
          
          // Update cache with optimistic update
          if (_currentEventId != null) {
            await _cacheService.updateAttendeeInCache(_currentEventId!, updatedAttendee);
            print('💾 PROVIDER: Cached optimistic ID check-in for ${updatedAttendee.fullName}');
          }
        }
        
        _updateQueuedActionsCount();
        _setCheckInError(null);
        return true; // Return true for offline queuing
      }
    } catch (e) {
      print('🔍 PROVIDER: Error occurred: $e');
      // If online request fails, try to queue it offline
      if (_connectivityService.isOnline) {
        _setCheckInError('Check-in failed: ${e.toString()}');
        return false;
      } else {
        // Queue the action for later sync
        await _queueService.queueCheckInById(
          eventId: _currentEventId!,
          attendeeId: attendeeId,
          timestamp: DateTime.now(),
        );
        
        _updateQueuedActionsCount();
        _setCheckInError(null);
        return true;
      }
    } finally {
      _setCheckingIn(false);
    }
  }

  // Add walk-in attendee
  Future<bool> addWalkIn({
    required String firstName,
    required String lastName,
    required String email,
    required String ticketType,
    bool isVip = false,
  }) async {
    if (_currentEventId == null) {
      _setError('No event selected');
      return false;
    }

    _setLoading(true);
    _setError(null);

    try {
      // Check if we're online
      if (_connectivityService.isOnline) {
        final result = await _apiService.addWalkIn(
          eventId: _currentEventId!,
          firstName: firstName,
          lastName: lastName,
          email: email,
          ticketType: ticketType,
          isVip: isVip,
        );

        if (result['success'] == true) {
          // Add the new attendee to the local list
          final attendeeData = result['attendee'];
          if (attendeeData != null) {
            final newAttendee = Attendee.fromJson(attendeeData);
            _attendees.add(newAttendee);
            _lastCreatedAttendee = newAttendee; // Store for badge printing
            
            // Update cache
            if (_currentEventId != null) {
              await _cacheService.updateAttendeeInCache(_currentEventId!, newAttendee);
            }
            
            notifyListeners();
          }
          
          _setError(null);
          return true;
        } else {
          _setError(result['message'] ?? 'Failed to add walk-in');
          return false;
        }
      } else {
        // We're offline, queue the action
        await _queueService.queueWalkInRegistration(
          eventId: _currentEventId!,
          firstName: firstName,
          lastName: lastName,
          email: email,
          ticketType: ticketType,
          isVip: isVip,
          timestamp: DateTime.now(),
        );
        
        _updateQueuedActionsCount();
        _setError(null);
        return true; // Return true for offline queuing
      }
    } catch (e) {
      // If online request fails, try to queue it offline
      if (_connectivityService.isOnline) {
        _setError('Failed to add walk-in: ${e.toString()}');
        return false;
      } else {
        // Queue the action for later sync
        await _queueService.queueWalkInRegistration(
          eventId: _currentEventId!,
          firstName: firstName,
          lastName: lastName,
          email: email,
          ticketType: ticketType,
          isVip: isVip,
          timestamp: DateTime.now(),
        );
        
        _updateQueuedActionsCount();
        _setError(null);
        return true;
      }
    } finally {
      _setLoading(false);
    }
  }

  // Search attendees
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

  // Get attendee by ID
  Attendee? getAttendeeById(String attendeeId) {
    try {
      return _attendees.firstWhere((attendee) => attendee.id == attendeeId);
    } catch (e) {
      return null;
    }
  }

  // Get attendee by QR code
  Attendee? getAttendeeByQR(String qrCode) {
    try {
      return _attendees.firstWhere((attendee) => attendee.qrCode == qrCode);
    } catch (e) {
      return null;
    }
  }

  // Clear check-in error
  void clearCheckInError() {
    _setCheckInError(null);
  }

  // Clear last created attendee
  void clearLastCreatedAttendee() {
    _lastCreatedAttendee = null;
    notifyListeners();
  }

  // Print badge for attendee
  Future<void> printBadge(String attendeeId) async {
    try {
      _setLoading(true);
      _setError(null);
      
      // Find the attendee
      final attendee = _attendees.firstWhere((a) => a.id == attendeeId);
      
      // Use BadgeProvider for actual printing
      // This will be handled by the UI layer that has access to BadgeProvider
      // For now, we'll just update the badgeGenerated status
      final attendeeIndex = _attendees.indexWhere((attendee) => attendee.id == attendeeId);
      if (attendeeIndex != -1) {
        _attendees[attendeeIndex] = _attendees[attendeeIndex].copyWith(badgeGenerated: true);
        notifyListeners();
      }
      
    } catch (e) {
      _setError('Failed to print badge: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Clear all data (when switching events)
  void clearData() {
    _attendees.clear();
    _currentEventId = null;
    _lastRefresh = null;
    _searchTerm = '';
    _statusFilter = 'all';
    _setError(null);
    _setCheckInError(null);
    _lastScannedQR = null;
    _lastCreatedAttendee = null;
    notifyListeners();
  }
  
  // Clear cache for current event
  Future<void> clearCurrentEventCache() async {
    if (_currentEventId != null) {
      await _cacheService.clearEventCache(_currentEventId!);
    }
  }

  // Check if attendees need refresh (older than 2 minutes)
  bool get needsRefresh {
    if (_lastRefresh == null) return true;
    final now = DateTime.now();
    return now.difference(_lastRefresh!).inMinutes > 2;
  }

  // Private helper methods
  void _updateAttendeeInList(Attendee updatedAttendee) {
    print('🔍 PROVIDER: _updateAttendeeInList called for ${updatedAttendee.fullName}');
    final index = _attendees.indexWhere((attendee) => attendee.id == updatedAttendee.id);
    print('🔍 PROVIDER: Found attendee at index: $index');
    if (index != -1) {
      print('🔍 PROVIDER: Updating attendee from ${_attendees[index].isCheckedIn} to ${updatedAttendee.isCheckedIn}');
      _attendees[index] = updatedAttendee;
      print('🔍 PROVIDER: Calling notifyListeners()');
      notifyListeners();
      print('🔍 PROVIDER: notifyListeners() completed');
    } else {
      print('🔍 PROVIDER: Attendee not found in list');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _setCheckingIn(bool checkingIn) {
    _isCheckingIn = checkingIn;
    notifyListeners();
  }

  void _setCheckInError(String? error) {
    _checkInError = error;
    notifyListeners();
  }

  void _updateQueuedActionsCount() {
    _queuedActionsCount = _queueService.queueLength;
    print('📊 PROVIDER: Queue count updated to $_queuedActionsCount');
    notifyListeners();
  }
  
  // Public method to refresh queue count (for manual refresh)
  void refreshQueueCount() {
    _updateQueuedActionsCount();
  }
  
  // Verify queue state after sync
  void verifyQueueState() {
    final actualQueueLength = _queueService.queueLength;
    print('🔍 PROVIDER: Queue verification:');
    print('   - Stored count: $_queuedActionsCount');
    print('   - Actual queue length: $actualQueueLength');
    
    if (_queuedActionsCount != actualQueueLength) {
      print('⚠️ PROVIDER: Queue count mismatch! Updating...');
      _updateQueuedActionsCount();
    } else {
      print('✅ PROVIDER: Queue count is accurate');
    }
  }

  // Initialize offline support
  Future<void> initializeOfflineSupport({SyncService? syncService}) async {
    await _queueService.initialize();
    await _cacheService.initialize();
    
    // CRITICAL FIX: Initialize connectivity service first
    await _connectivityService.initialize();
    
    // Store sync service reference
    _syncService = syncService;
    
    _updateQueuedActionsCount();
    
    // Listen for connectivity changes
    _connectivityService.addListener(_onConnectivityChanged);
    
    // Listen for sync completion if sync service is available
    if (_syncService != null) {
      _syncService!.addSyncCompletionCallback(_onSyncCompleted);
    }
    
    // Start periodic queue count refresh to ensure UI stays in sync
    _startQueueCountRefreshTimer();
  }
  
  // Start periodic queue count refresh
  void _startQueueCountRefreshTimer() {
    _queueCountRefreshTimer?.cancel();
    _queueCountRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final oldCount = _queuedActionsCount;
      _updateQueuedActionsCount();
      if (oldCount != _queuedActionsCount) {
        print('📊 PROVIDER: Queue count changed from $oldCount to $_queuedActionsCount (periodic refresh)');
      }
    });
  }
  
  // Stop periodic queue count refresh
  void _stopQueueCountRefreshTimer() {
    _queueCountRefreshTimer?.cancel();
    _queueCountRefreshTimer = null;
  }
  
  // Handle connectivity changes
  void _onConnectivityChanged() {
    final wasOffline = _isOffline;
    _isOffline = !_connectivityService.isOnline;
    
    print('🌐 PROVIDER: Connectivity changed - isOffline: $_isOffline (was: $wasOffline)');
    
    // When coming back online, refresh data after sync completes
    if (wasOffline && !_isOffline) {
      print('✅ PROVIDER: Connection restored! Will refresh after sync completes');
    }
    
    notifyListeners();
  }
  
  // Handle sync completion
  void _onSyncCompleted(dynamic result) {
    print('🔄 PROVIDER: Sync completed callback triggered');
    print('   - Success: ${result.success}');
    print('   - Processed: ${result.processedActions}');
    print('   - Failed: ${result.failedActions}');
    print('   - Queue length before update: ${_queuedActionsCount}');
    
    // Update queue count immediately
    _updateQueuedActionsCount();
    
    print('   - Queue length after update: ${_queuedActionsCount}');
    
    // Verify queue state is accurate
    verifyQueueState();
    
    if (_queuedActionsCount == 0) {
      print('✅ PROVIDER: All pending actions cleared! "Syncing Data" modal should hide');
    } else {
      print('⚠️ PROVIDER: Still ${_queuedActionsCount} actions pending');
    }
    
    // Always refresh attendees after sync (success or failure) to ensure UI is accurate
    if (_connectivityService.isOnline) {
      print('✅ PROVIDER: Sync completed, triggering silent refresh');
      silentRefreshAttendees();
    } else {
      print('ℹ️ PROVIDER: Sync completed but offline, no refresh');
    }
  }

  // Legacy method aliases for compatibility
  Future<void> fetchAttendees(String eventId) async {
    await loadAttendees(eventId);
  }

  Future<bool> addWalkInAttendee({
    required String eventId,
    required String firstName,
    required String lastName,
    required String email,
    required String ticketType,
    bool isVip = false,
  }) async {
    return await addWalkIn(
      firstName: firstName,
      lastName: lastName,
      email: email,
      ticketType: ticketType,
      isVip: isVip,
    );
  }


  String? get errorMessage => _error;
  String? get selectedEventId => _currentEventId;

  @override
  void dispose() {
    _apiService.dispose();
    _connectivityService.removeListener(_onConnectivityChanged);
    if (_syncService != null) {
      _syncService!.removeSyncCompletionCallback(_onSyncCompleted);
    }
    _stopQueueCountRefreshTimer();
    super.dispose();
  }
}