import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/event.dart';
import '../providers/attendee_provider.dart';
import '../providers/badge_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/qr_scanner_screen.dart';
import '../screens/walk_in_screen.dart';
import '../screens/search_attendees_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/connectivity_status_widget.dart';
import '../widgets/offline_queue_dialog.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../utils/responsive_utils.dart';

class CheckInHubScreen extends StatefulWidget {
  final Event event;

  const CheckInHubScreen({
    Key? key,
    required this.event,
  }) : super(key: key);

  @override
  State<CheckInHubScreen> createState() => _CheckInHubScreenState();
}

class _CheckInHubScreenState extends State<CheckInHubScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeTabController();
    // Defer data loading until after the build phase to avoid setState() during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEventData();
    });
  }

  void _initializeTabController() {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final savedIndex = settingsProvider.selectedTabIndex;
    
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: savedIndex.clamp(0, 2),
    );
    
    _currentIndex = _tabController.index;
    
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentIndex = _tabController.index;
        });
        
        // Save selected tab index
        settingsProvider.updateSelectedTabIndex(_currentIndex);
      }
    });
  }

  Future<void> _loadEventData() async {
    final attendeeProvider = Provider.of<AttendeeProvider>(context, listen: false);
    final badgeProvider = Provider.of<BadgeProvider>(context, listen: false);

    try {
      // Cache the event data for template selection
      badgeProvider.cacheEvent(widget.event);

      // CRITICAL FIX: Templates are now loaded globally at app start (like web app)
      // Load attendees for this event - loadFromCacheFirst=true for instant UI
      print('🔍 CHECK-IN HUB: Loading attendees with cache-first strategy');
      
      // First try to load cached data instantly
      await attendeeProvider.loadCachedAttendees(widget.event.id);
      
      // Then load fresh data if online
      await attendeeProvider.loadAttendees(widget.event.id, loadFromCacheFirst: true);

      // Log current badge provider state for debugging
      print('🔍 CHECK-IN HUB: Badge provider state:');
      print('  - Templates loaded: ${badgeProvider.templates.length}');
      print('  - Event cached: ${badgeProvider.selectedTemplate != null ? badgeProvider.selectedTemplate!.name : "none"}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load event data: ${e.toString()}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    final attendeeProvider = Provider.of<AttendeeProvider>(context, listen: false);
    await attendeeProvider.refreshAttendees();
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.event.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.event.venue,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        actions: [
          Consumer<AttendeeProvider>(
            builder: (context, attendeeProvider, child) {
              final queuedCount = attendeeProvider.queuedActionsCount;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.sync, color: Colors.white),
                    onPressed: _showOfflineQueueDialog,
                    tooltip: 'Offline Queue',
                  ),
                  if (queuedCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          queuedCount > 99 ? '99+' : queuedCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _navigateToSettings,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Connectivity status banner
          const ConnectivityStatusBanner(),
          
          // Event stats header
          _buildEventStatsHeader(),
          
          // Tab bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryColor,
              tabs: const [
                Tab(
                  icon: Icon(Icons.qr_code_scanner),
                  text: 'QR Scanner',
                ),
                Tab(
                  icon: Icon(Icons.person_add),
                  text: 'Walk-in',
                ),
                Tab(
                  icon: Icon(Icons.search),
                  text: 'Search',
                ),
              ],
            ),
          ),
          
          // Tab views
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      QRScannerScreen(event: widget.event),
                      WalkInScreen(event: widget.event),
                      SearchAttendeesScreen(event: widget.event),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildEventStatsHeader() {
    return Consumer<AttendeeProvider>(
      builder: (context, attendeeProvider, child) {
        final responsivePadding = ResponsiveUtils.getResponsivePadding(context);
        return Container(
          padding: EdgeInsets.all(responsivePadding),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Event status indicator
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: widget.event.isLive 
                            ? AppTheme.successColor 
                            : AppTheme.warningColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(),
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _getStatusText(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _formatEventDate(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Statistics row
              ResponsiveUtils.shouldUseCompactLayout(context)
                  ? Column(
                      children: [
                        Row(
                          children: [
                            _buildStatCard(
                              'Total',
                              attendeeProvider.totalAttendees.toString(),
                              Icons.people,
                            ),
                            const SizedBox(width: 8),
                            _buildStatCard(
                              'Checked In',
                              attendeeProvider.checkedInCount.toString(),
                              Icons.check_circle,
                              color: AppTheme.successColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildStatCard(
                              'Remaining',
                              attendeeProvider.notCheckedInCount.toString(),
                              Icons.pending,
                              color: AppTheme.warningColor,
                            ),
                            const SizedBox(width: 8),
                            _buildStatCard(
                              'VIP',
                              attendeeProvider.vipCount.toString(),
                              Icons.star,
                              color: AppTheme.warningColor,
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        _buildStatCard(
                          'Total',
                          attendeeProvider.totalAttendees.toString(),
                          Icons.people,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          'Checked In',
                          attendeeProvider.checkedInCount.toString(),
                          Icons.check_circle,
                          color: AppTheme.successColor,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          'Remaining',
                          attendeeProvider.notCheckedInCount.toString(),
                          Icons.pending,
                          color: AppTheme.warningColor,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          'VIP',
                          attendeeProvider.vipCount.toString(),
                          Icons.star,
                          color: AppTheme.warningColor,
                        ),
                      ],
                    ),
              
              const SizedBox(height: 12),
              
              // Progress bar
              _buildProgressBar(attendeeProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, {Color? color}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(ResponsiveUtils.isMobile(context) ? 8 : 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color ?? Colors.white,
              size: ResponsiveUtils.getIconSize(context, 20),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, 16),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, 10),
                  color: Colors.white.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(AttendeeProvider attendeeProvider) {
    final percentage = attendeeProvider.checkInPercentage;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Check-in Progress',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
            Text(
              '${percentage.toInt()}%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              percentage >= 80 
                  ? AppTheme.successColor 
                  : percentage >= 50 
                      ? AppTheme.warningColor 
                      : AppTheme.errorColor,
            ),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          _tabController.animateTo(index);
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.textSecondaryColor,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            activeIcon: Icon(Icons.qr_code_scanner),
            label: 'QR Scanner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add),
            activeIcon: Icon(Icons.person_add),
            label: 'Walk-In',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            activeIcon: Icon(Icons.search),
            label: 'Search',
          ),
        ],
      ),
    );
  }

  String _formatEventDate() {
    final startDate = widget.event.startDate;
    final endDate = widget.event.endDate;
    
    // Check if it's the same day
    if (startDate.year == endDate.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day) {
      return '${_formatDate(startDate)} • ${_formatTime(startDate)} - ${_formatTime(endDate)}';
    } else {
      return '${_formatDate(startDate)} - ${_formatDate(endDate)}';
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    return '${months[date.month - 1]} ${date.day}';
  }

  IconData _getStatusIcon() {
    switch (widget.event.displayStatus) {
      case 'live':
        return Icons.live_tv;
      case 'ended':
        return Icons.event_available;
      case 'upcoming':
      default:
        return Icons.schedule;
    }
  }

  String _getStatusText() {
    switch (widget.event.displayStatus) {
      case 'live':
        return 'LIVE EVENT';
      case 'ended':
        return 'ENDED';
      case 'upcoming':
      default:
        return 'UPCOMING';
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour == 0 ? 12 : time.hour > 12 ? time.hour - 12 : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    
    return '$hour:$minute $period';
  }

  void _showOfflineQueueDialog() {
    showDialog(
      context: context,
      builder: (context) => const OfflineQueueDialog(),
    ).then((_) {
      // Refresh queue count when dialog closes
      final attendeeProvider = Provider.of<AttendeeProvider>(context, listen: false);
      attendeeProvider.refreshQueueCount();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}