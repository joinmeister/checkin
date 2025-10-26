import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/attendee.dart';

class AttendeeCacheService {
  static final AttendeeCacheService _instance = AttendeeCacheService._internal();
  factory AttendeeCacheService() => _instance;
  AttendeeCacheService._internal();

  static const String _boxName = 'attendee_cache';
  Box? _box;

  // Initialize the cache service
  Future<void> initialize() async {
    try {
      _box = await Hive.openBox(_boxName);
      print('📦 CACHE: Attendee cache initialized');
    } catch (e) {
      print('❌ CACHE: Error initializing attendee cache: $e');
    }
  }

  // Cache attendees for a specific event
  Future<void> cacheAttendees(String eventId, List<Attendee> attendees) async {
    try {
      if (_box == null) await initialize();
      
      final attendeesJson = attendees.map((a) => a.toJson()).toList();
      await _box!.put('attendees_$eventId', jsonEncode(attendeesJson));
      await _box!.put('attendees_${eventId}_timestamp', DateTime.now().toIso8601String());
      
      print('✅ CACHE: Cached ${attendees.length} attendees for event $eventId');
    } catch (e) {
      print('❌ CACHE: Error caching attendees: $e');
    }
  }

  // Get cached attendees for a specific event
  Future<List<Attendee>?> getCachedAttendees(String eventId) async {
    try {
      if (_box == null) await initialize();
      
      final cachedData = _box!.get('attendees_$eventId');
      if (cachedData == null) {
        print('📦 CACHE: No cached attendees for event $eventId');
        return null;
      }

      final List<dynamic> attendeesJson = jsonDecode(cachedData);
      final attendees = attendeesJson.map((json) => Attendee.fromJson(json)).toList();
      
      final timestamp = _box!.get('attendees_${eventId}_timestamp');
      print('✅ CACHE: Loaded ${attendees.length} attendees from cache (cached at: $timestamp)');
      
      return attendees;
    } catch (e) {
      print('❌ CACHE: Error getting cached attendees: $e');
      return null;
    }
  }

  // Update a single attendee in cache
  Future<void> updateAttendeeInCache(String eventId, Attendee attendee) async {
    try {
      final cachedAttendees = await getCachedAttendees(eventId);
      if (cachedAttendees == null) return;

      final index = cachedAttendees.indexWhere((a) => a.id == attendee.id);
      if (index != -1) {
        final oldAttendee = cachedAttendees[index];
        cachedAttendees[index] = attendee;
        await cacheAttendees(eventId, cachedAttendees);
        print('✅ CACHE: Updated attendee ${attendee.fullName} in cache');
        print('   - Check-in status: ${oldAttendee.isCheckedIn} → ${attendee.isCheckedIn}');
      } else {
        // Attendee not found, add to cache
        cachedAttendees.add(attendee);
        await cacheAttendees(eventId, cachedAttendees);
        print('✅ CACHE: Added new attendee ${attendee.fullName} to cache');
        print('   - Check-in status: ${attendee.isCheckedIn}');
      }
    } catch (e) {
      print('❌ CACHE: Error updating attendee in cache: $e');
    }
  }

  // Clear cache for a specific event
  Future<void> clearEventCache(String eventId) async {
    try {
      if (_box == null) await initialize();
      
      await _box!.delete('attendees_$eventId');
      await _box!.delete('attendees_${eventId}_timestamp');
      
      print('✅ CACHE: Cleared cache for event $eventId');
    } catch (e) {
      print('❌ CACHE: Error clearing event cache: $e');
    }
  }

  // Clear all cache
  Future<void> clearAllCache() async {
    try {
      if (_box == null) await initialize();
      
      await _box!.clear();
      print('✅ CACHE: Cleared all cache');
    } catch (e) {
      print('❌ CACHE: Error clearing all cache: $e');
    }
  }

  // Check if cache exists for event
  Future<bool> hasCachedData(String eventId) async {
    try {
      if (_box == null) await initialize();
      return _box!.containsKey('attendees_$eventId');
    } catch (e) {
      print('❌ CACHE: Error checking cache: $e');
      return false;
    }
  }

  // Get cache timestamp
  Future<DateTime?> getCacheTimestamp(String eventId) async {
    try {
      if (_box == null) await initialize();
      
      final timestamp = _box!.get('attendees_${eventId}_timestamp');
      if (timestamp != null) {
        return DateTime.parse(timestamp);
      }
      return null;
    } catch (e) {
      print('❌ CACHE: Error getting cache timestamp: $e');
      return null;
    }
  }

  // Check if cache is stale (older than specified duration)
  Future<bool> isCacheStale(String eventId, {Duration maxAge = const Duration(minutes: 5)}) async {
    try {
      final timestamp = await getCacheTimestamp(eventId);
      if (timestamp == null) return true;
      
      final age = DateTime.now().difference(timestamp);
      return age > maxAge;
    } catch (e) {
      print('❌ CACHE: Error checking if cache is stale: $e');
      return true;
    }
  }
}

