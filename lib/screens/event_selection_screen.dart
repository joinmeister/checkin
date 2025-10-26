import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import '../providers/event_provider.dart';
import '../providers/attendee_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/badge_provider.dart';
import '../models/event.dart';
import '../services/sync_service.dart';
import '../services/connectivity_service.dart';
import '../widgets/event_card.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/filter_chips.dart';
import '../widgets/loading_shimmer.dart';
import '../screens/check_in_hub_screen.dart';
import '../screens/settings_screen.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

class EventSelectionScreen extends StatefulWidget {
  const EventSelectionScreen({Key? key}) : super(key: key);

  @override
  State<EventSelectionScreen> createState() => _EventSelectionScreenState();
}

class _EventSelectionScreenState extends State<EventSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _setupScrollListener();
  }

  void _initializeData() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('📱 SCREEN: Starting EventSelectionScreen initialization...');
      
      try {
        final eventProvider = Provider.of<EventProvider>(context, listen: false);
        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
        final attendeeProvider = Provider.of<AttendeeProvider>(context, listen: false);
        final badgeProvider = Provider.of<BadgeProvider>(context, listen: false);
        final syncService = Provider.of<SyncService>(context, listen: false);
        final connectivityService = Provider.of<ConnectivityService>(context, listen: false);
        
        print('✅ SCREEN: All providers obtained successfully');
        
        // Initialize settings first
        print('⚙️  SCREEN: Initializing settings...');
        await settingsProvider.initializeSettings();
        print('✅ SCREEN: Settings initialized');
        
        // Initialize connectivity service (must be before offline support)
        print('🌐 SCREEN: Initializing connectivity service...');
        await connectivityService.initialize();
        print('✅ SCREEN: Connectivity service initialized');
        
        // Initialize sync service
        print('🔄 SCREEN: Initializing sync service...');
        await syncService.initialize();
        print('✅ SCREEN: Sync service initialized');
        
        // Initialize offline support (includes cache and queue services)
        print('💾 SCREEN: Initializing offline support...');
        await attendeeProvider.initializeOfflineSupport(syncService: syncService);
        print('✅ SCREEN: Offline support initialized');
        
        // CRITICAL FIX: Load ALL badge templates globally (like web app)
        print('🎫 SCREEN: Fetching badge templates...');
        badgeProvider.fetchTemplates();
        print('✅ SCREEN: Badge templates fetch started');
        
        // Initialize printers for direct printing
        print('🖨️  SCREEN: Fetching available printers...');
        badgeProvider.fetchAvailablePrinters();
        print('✅ SCREEN: Printer fetch started');
        
        // Load events
        print('📅 SCREEN: Loading events...');
        eventProvider.loadEvents();
        print('✅ SCREEN: Event loading started');
        
        print('✅ APP: All services initialized successfully');
      } catch (e, stackTrace) {
        print('❌ SCREEN: Error during initialization: $e');
        print('❌ SCREEN: Stack trace: $stackTrace');
        
        // Show error to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Initialization error: ${e.toString()}'),
              duration: const Duration(seconds: 10),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: _initializeData,
              ),
            ),
          );
        }
      }
    });
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Hide keyboard when scrolling
      if (_scrollController.position.userScrollDirection != ScrollDirection.idle) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  Future<void> _refreshEvents() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });

    try {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      await eventProvider.refreshEvents();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  void _onEventSelected(Event event) {
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final badgeProvider = Provider.of<BadgeProvider>(context, listen: false);
    
    // Select the event
    eventProvider.selectEvent(event);
    
    // CRITICAL FIX: Cache event data for badge template selection
    badgeProvider.cacheEvent(event);
    
    // Save selected event ID to settings
    settingsProvider.updateSelectedEventId(event.id);
    
    // Navigate to check-in hub
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CheckInHubScreen(event: event),
      ),
    );
  }

  void _onSearchChanged(String value) {
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    eventProvider.updateSearchTerm(value);
  }

  void _onFilterChanged(String filter) {
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    eventProvider.updateStatusFilter(filter);
  }

  void _clearFilters() {
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    eventProvider.clearFilters();
    _searchController.clear();
  }

  void _navigateToSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          AppConstants.appName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _navigateToSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Consumer<EventProvider>(
        builder: (context, eventProvider, child) {
          return NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: _buildHeader(eventProvider),
                ),
                SliverToBoxAdapter(
                  child: _buildSearchAndFilters(eventProvider),
                ),
              ];
            },
            body: _buildEventsList(eventProvider),
          );
        },
      ),
    );
  }

  Widget _buildHeader(EventProvider eventProvider) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Event Management',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select an event to start check-in',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStatCard(
                'Total Events',
                eventProvider.events.length.toString(),
                Icons.event,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Live Events',
                eventProvider.liveEventsCount.toString(),
                Icons.live_tv,
                color: AppTheme.successColor,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Total Attendees',
                eventProvider.totalAttendees.toString(),
                Icons.people,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, {Color? color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color ?? Colors.white,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(EventProvider eventProvider) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Search bar
          SearchBarWidget(
            controller: _searchController,
            hintText: 'Search events by name, venue...',
            onChanged: _onSearchChanged,
            onClear: () {
              _searchController.clear();
              _onSearchChanged('');
            },
          ),
          const SizedBox(height: 8),
          
          // Filter chips
          FilterChips(
            selectedFilter: eventProvider.statusFilter,
            onFilterChanged: _onFilterChanged,
            filters: const [
              {'value': 'all', 'label': 'All Events'},
              {'value': 'live', 'label': 'Live'},
              {'value': 'upcoming', 'label': 'Upcoming'},
              {'value': 'completed', 'label': 'Completed'},
              {'value': 'draft', 'label': 'Draft'},
            ],
          ),
          
          // Clear filters button
          if (eventProvider.searchTerm.isNotEmpty || eventProvider.statusFilter != 'all')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear Filters'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventsList(EventProvider eventProvider) {
    if (eventProvider.isLoading && eventProvider.events.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            child: const LoadingShimmer(),
          ),
        ],
      );
    }

    if (eventProvider.error != null) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            child: _buildErrorState(eventProvider),
          ),
        ],
      );
    }

    final filteredEvents = eventProvider.filteredEvents;

    if (filteredEvents.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            child: _buildEmptyState(eventProvider),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshEvents,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filteredEvents.length,
        itemBuilder: (context, index) {
          final event = filteredEvents[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: EventCard(
              event: event,
              onTap: () => _onEventSelected(event),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(EventProvider eventProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load events',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              eventProvider.error ?? 'Unknown error occurred',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshEvents,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(EventProvider eventProvider) {
    final hasFilters = eventProvider.searchTerm.isNotEmpty || 
                     eventProvider.statusFilter != 'all';
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilters ? Icons.search_off : Icons.event_busy,
              size: 64,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilters ? 'No events found' : 'No events available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters 
                ? 'Try adjusting your search or filters'
                : 'Events will appear here when they are created',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasFilters) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear),
                label: const Text('Clear Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}