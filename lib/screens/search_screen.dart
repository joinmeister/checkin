import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/attendee_provider.dart';
import '../providers/event_provider.dart';
import '../providers/badge_provider.dart';
import '../providers/settings_provider.dart';
import '../services/analytics_service.dart';
import '../models/attendee.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../utils/responsive_utils.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/filter_chips.dart';
import '../widgets/loading_shimmer.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  
  final List<String> _filters = [
    'All',
    'Checked In',
    'Not Checked In',
    'VIP',
    'Regular',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Consumer2<EventProvider, AttendeeProvider>(
        builder: (context, eventProvider, attendeeProvider, child) {
          if (eventProvider.selectedEvent == null) {
            return const Center(
              child: Text('No event selected'),
            );
          }

          return Column(
            children: [
              // Search and Filter Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Search bar
                    SearchBarWidget(
                      controller: _searchController,
                      hintText: 'Search by name or email...',
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      onClear: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Filter chips
                    FilterChips(
                      filters: _filters,
                      selectedFilter: _selectedFilter,
                      onFilterSelected: (filter) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                    ),
                  ],
                ),
              ),
              
              // Attendee List
              Expanded(
                child: _buildAttendeeList(attendeeProvider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAttendeeList(AttendeeProvider attendeeProvider) {
    if (attendeeProvider.isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 10,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: LoadingShimmer.card(),
        ),
      );
    }

    final filteredAttendees = _getFilteredAttendees(attendeeProvider.attendees);

    if (filteredAttendees.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        final eventProvider = Provider.of<EventProvider>(context, listen: false);
        if (eventProvider.selectedEvent != null) {
          await attendeeProvider.fetchAttendees(eventProvider.selectedEvent!.id);
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredAttendees.length,
        itemBuilder: (context, index) {
          final attendee = filteredAttendees[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildAttendeeCard(attendee, attendeeProvider),
          );
        },
      ),
    );
  }

  Widget _buildAttendeeCard(Attendee attendee, AttendeeProvider attendeeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: attendee.isCheckedIn ? null : () => _showCheckInDialog(attendee, attendeeProvider),
          child: Padding(
            padding: ResponsiveUtils.getResponsivePaddingInsets(context),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: attendee.isVip 
                        ? AppTheme.warningColor.withOpacity(0.1)
                        : AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    attendee.isVip ? Icons.star : Icons.person,
                    color: attendee.isVip ? AppTheme.warningColor : AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Attendee Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        attendee.fullName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Email
                      Text(
                        attendee.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Tags
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          // Ticket Type
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              attendee.ticketType,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          
                          if (attendee.isVip)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.warningColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 12,
                                    color: AppTheme.warningColor,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'VIP',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.warningColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Status and Action
                Column(
                  children: [
                    // Check-in status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: attendee.isCheckedIn 
                            ? AppTheme.successColor.withOpacity(0.1)
                            : AppTheme.warningColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            attendee.isCheckedIn ? Icons.check_circle : Icons.schedule,
                            size: 14,
                            color: attendee.isCheckedIn ? AppTheme.successColor : AppTheme.warningColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            attendee.isCheckedIn ? 'Checked In' : 'Pending',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: attendee.isCheckedIn ? AppTheme.successColor : AppTheme.warningColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    if (attendee.isCheckedIn && attendee.updatedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        attendee.formattedCheckInTime,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                    
                    if (!attendee.isCheckedIn) ...[
                      const SizedBox(height: 8),
                      Icon(
                        Icons.touch_app,
                        size: 20,
                        color: AppTheme.primaryColor,
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _printBadge(attendee),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.print,
                                size: 16,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Print',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;
    
    if (_searchQuery.isNotEmpty) {
      message = 'No attendees found for "$_searchQuery"';
      icon = Icons.search_off;
    } else if (_selectedFilter != 'All') {
      message = 'No attendees found for filter "$_selectedFilter"';
      icon = Icons.filter_list_off;
    } else {
      message = 'No attendees found';
      icon = Icons.people_outline;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filters',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  List<Attendee> _getFilteredAttendees(List<Attendee> attendees) {
    List<Attendee> filtered = attendees;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((attendee) {
        final query = _searchQuery.toLowerCase();
        return attendee.fullName.toLowerCase().contains(query) ||
               attendee.email.toLowerCase().contains(query);
      }).toList();
    }

    // Apply status filter
    switch (_selectedFilter) {
      case 'Checked In':
        filtered = filtered.where((attendee) => attendee.isCheckedIn).toList();
        break;
      case 'Not Checked In':
        filtered = filtered.where((attendee) => !attendee.isCheckedIn).toList();
        break;
      case 'VIP':
        filtered = filtered.where((attendee) => attendee.isVip).toList();
        break;
      case 'Regular':
        filtered = filtered.where((attendee) => !attendee.isVip).toList();
        break;
    }

    // Sort by name
    filtered.sort((a, b) => a.fullName.compareTo(b.fullName));

    return filtered;
  }

  void _showCheckInDialog(Attendee attendee, AttendeeProvider attendeeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Check In Attendee',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to check in:',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: attendee.isVip 
                          ? AppTheme.warningColor.withOpacity(0.1)
                          : AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      attendee.isVip ? Icons.star : Icons.person,
                      color: attendee.isVip ? AppTheme.warningColor : AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attendee.fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                        ),
                        Text(
                          attendee.email,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _checkInAttendee(attendee, attendeeProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Check In'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkInAttendee(Attendee attendee, AttendeeProvider attendeeProvider) async {
    final analyticsService = AnalyticsService();
    final attendeeId = attendee.id;
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    
    print('🔍 CHECK-IN: Starting check-in for ${attendee.fullName}');
    
    // Show initial status modal
    print('🔍 CHECK-IN: Showing initial status modal');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CheckInStatusDialog(
        attendee: attendee,
        message: 'Checking in...',
        isComplete: false,
        isError: false,
      ),
    );
    
    // Start analytics timing
    analyticsService.startCheckInProcess(attendeeId);
    
    try {
      print('🔍 CHECK-IN: Calling provider checkInAttendeeById');
      final success = await attendeeProvider.checkInAttendeeById(attendee.id);
      print('🔍 CHECK-IN: Provider returned success: $success');
      
      if (success) {
        // Provide haptic feedback
        HapticFeedback.lightImpact();
        
        // Check if attendee was already checked in
        final wasAlreadyCheckedIn = attendeeProvider.wasAlreadyCheckedIn;
        print('🔍 CHECK-IN: Was already checked in: $wasAlreadyCheckedIn');
        
        // Close current modal and show success modal
        print('🔍 CHECK-IN: Closing initial modal and showing success modal');
        Navigator.of(context).pop();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _CheckInStatusDialog(
            attendee: attendee,
            message: wasAlreadyCheckedIn ? 'Already checked in' : 'Check-in successful!',
            isComplete: true,
            isError: false,
          ),
        );
        
        // Auto-print badge after successful check-in
        print('🔍 CHECK-IN: Starting auto-print');
        await _handleBadgePrinting(attendee, analyticsService, attendeeId);
        print('🔍 CHECK-IN: Auto-print completed');
        
        // Complete analytics
        analyticsService.completeCheckInProcess(
          attendeeId: attendeeId,
          eventId: eventProvider.selectedEvent?.id ?? '',
          checkinType: AppConstants.idCheckType,
        );
        
        // Close status modal after delay
        await Future.delayed(const Duration(seconds: 2));
        Navigator.of(context).pop(); // Close status modal
        print('🔍 CHECK-IN: Success modal closed');
        
      } else {
        print('🔍 CHECK-IN: Check-in failed');
        // Complete analytics even on failure
        analyticsService.completeCheckInProcess(
          attendeeId: attendeeId,
          eventId: eventProvider.selectedEvent?.id ?? '',
          checkinType: AppConstants.idCheckType,
        );
        
        // Close current modal and show error modal
        Navigator.of(context).pop();
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _CheckInStatusDialog(
            attendee: attendee,
            message: 'Check-in failed',
            isComplete: true,
            isError: true,
          ),
        );
        
        // Close status modal after delay
        await Future.delayed(const Duration(seconds: 2));
        Navigator.of(context).pop(); // Close status modal
      }
    } catch (e) {
      print('🔍 CHECK-IN: Error occurred: $e');
      // Complete analytics on error
      analyticsService.completeCheckInProcess(
        attendeeId: attendeeId,
        eventId: eventProvider.selectedEvent?.id ?? '',
        checkinType: AppConstants.idCheckType,
      );
      
      // Close current modal and show error modal
      Navigator.of(context).pop();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _CheckInStatusDialog(
          attendee: attendee,
          message: 'Error: ${e.toString()}',
          isComplete: true,
          isError: true,
        ),
      );
      
      // Close status modal after delay
      await Future.delayed(const Duration(seconds: 2));
      Navigator.of(context).pop(); // Close status modal
    }
  }


}

class _CheckInStatusDialog extends StatelessWidget {
  final Attendee attendee;
  final String message;
  final bool isComplete;
  final bool isError;

  const _CheckInStatusDialog({
    required this.attendee,
    required this.message,
    required this.isComplete,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
            children: [
          // Status icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isError 
                  ? AppTheme.errorColor.withOpacity(0.1)
                  : isComplete 
                      ? AppTheme.successColor.withOpacity(0.1)
                      : AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isError 
                  ? Icons.error
                  : isComplete 
                      ? Icons.check_circle
                      : Icons.hourglass_empty,
              size: 30,
              color: isError 
                  ? AppTheme.errorColor
                  : isComplete 
                      ? AppTheme.successColor
                      : AppTheme.primaryColor,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Attendee name
          Text(
            attendee.fullName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Status message
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: isError 
                  ? AppTheme.errorColor
                  : isComplete 
                      ? AppTheme.successColor
                      : AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          
          if (!isComplete) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

class _PrintStatusDialog extends StatelessWidget {
  final Attendee attendee;
  final String message;
  final bool isComplete;
  final bool isError;

  const _PrintStatusDialog({
    required this.attendee,
    required this.message,
    required this.isComplete,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isError 
                  ? AppTheme.errorColor.withOpacity(0.1)
                  : isComplete 
                      ? AppTheme.successColor.withOpacity(0.1)
                      : AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isError 
                  ? Icons.error
                  : isComplete 
                      ? Icons.check_circle
                      : Icons.print,
              size: 30,
              color: isError 
                  ? AppTheme.errorColor
                  : isComplete 
                      ? AppTheme.successColor
                      : AppTheme.primaryColor,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Attendee name
          Text(
            attendee.fullName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Status message
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: isError 
                  ? AppTheme.errorColor
                  : isComplete 
                      ? AppTheme.successColor
                      : AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          
          if (!isComplete) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Consumer2<EventProvider, AttendeeProvider>(
        builder: (context, eventProvider, attendeeProvider, child) {
          if (eventProvider.selectedEvent == null) {
            return const Center(
              child: Text('No event selected'),
            );
          }

          return Column(
            children: [
              // Search and Filter Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Search bar
                    SearchBarWidget(
                      controller: _searchController,
                      hintText: 'Search by name or email...',
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              
              // Attendee List
              Expanded(
                child: _buildAttendeeList(attendeeProvider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAttendeeList(AttendeeProvider attendeeProvider) {
    if (attendeeProvider.isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 10,
        itemBuilder: (context, index) => _buildLoadingCard(),
      );
    }

    final filteredAttendees = _getFilteredAttendees(attendeeProvider.attendees);

    if (filteredAttendees.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        final eventProvider = Provider.of<EventProvider>(context, listen: false);
        if (eventProvider.selectedEvent != null) {
          await attendeeProvider.fetchAttendees(eventProvider.selectedEvent!.id);
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredAttendees.length,
        itemBuilder: (context, index) {
          final attendee = filteredAttendees[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildAttendeeCard(attendee, attendeeProvider),
          );
        },
      ),
    );
  }

  Widget _buildAttendeeCard(Attendee attendee, AttendeeProvider attendeeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: attendee.isCheckedIn ? null : () => _showCheckInDialog(attendee, attendeeProvider),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: attendee.isVip 
                        ? AppTheme.warningColor.withOpacity(0.1)
                        : AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    attendee.isVip ? Icons.star : Icons.person,
                    color: attendee.isVip ? AppTheme.warningColor : AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Attendee Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        attendee.fullName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      
                      const SizedBox(height: 4),
                      
                      // Email
                      Text(
                        attendee.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Tags
                      Row(
                        children: [
                          // Ticket Type
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              attendee.ticketType,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          
                          if (attendee.isVip) ...[
              const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.warningColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star,
                                    size: 12,
                                    color: AppTheme.warningColor,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'VIP',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.warningColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Status and Action
                Column(
                  children: [
                    // Check-in status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: attendee.isCheckedIn 
                            ? AppTheme.successColor.withOpacity(0.1)
                            : AppTheme.warningColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            attendee.isCheckedIn ? Icons.check_circle : Icons.schedule,
                            size: 14,
                            color: attendee.isCheckedIn ? AppTheme.successColor : AppTheme.warningColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            attendee.isCheckedIn ? 'Checked In' : 'Pending',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: attendee.isCheckedIn ? AppTheme.successColor : AppTheme.warningColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    if (attendee.isCheckedIn && attendee.updatedAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        attendee.formattedCheckInTime,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                    
                    if (!attendee.isCheckedIn) ...[
                      const SizedBox(height: 8),
                      Icon(
                        Icons.touch_app,
                        size: 20,
                        color: AppTheme.primaryColor,
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _printBadge(attendee),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.print,
                                size: 16,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Print',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        ),
      );
    }

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No attendees found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search terms',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  List<Attendee> _getFilteredAttendees(List<Attendee> attendees) {
    if (_searchQuery.isEmpty) return attendees;
    
    final query = _searchQuery.toLowerCase();
    final filtered = attendees.where((attendee) {
      return attendee.firstName.toLowerCase().contains(query) ||
             attendee.lastName.toLowerCase().contains(query) ||
             attendee.email.toLowerCase().contains(query) ||
             attendee.fullName.toLowerCase().contains(query);
    }).toList();
    
    return filtered;
  }

  void _showCheckInDialog(Attendee attendee, AttendeeProvider attendeeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Check In',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: attendee.isVip 
                        ? AppTheme.warningColor.withOpacity(0.1)
                        : AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    attendee.isVip ? Icons.star : Icons.person,
                    color: attendee.isVip ? AppTheme.warningColor : AppTheme.primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attendee.fullName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      Text(
                        attendee.email,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _checkInAttendee(attendee, attendeeProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Check In'),
          ),
        ],
      ),
    );
  }

  Future<void> _printBadge(Attendee attendee) async {
    final analyticsService = AnalyticsService();
    final attendeeId = attendee.id;
    
    // Show printing status
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PrintStatusDialog(
        attendee: attendee,
        message: 'Printing badge...',
        isComplete: false,
        isError: false,
      ),
    );
    
    try {
      await _handleBadgePrinting(attendee, analyticsService, attendeeId);
      
      // Close current modal and show success modal
      Navigator.of(context).pop();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _PrintStatusDialog(
          attendee: attendee,
          message: 'Badge printed successfully!',
          isComplete: true,
          isError: false,
        ),
      );
      
      // Close status modal after delay
      await Future.delayed(const Duration(seconds: 2));
      Navigator.of(context).pop(); // Close status modal
      
    } catch (e) {
      // Close current modal and show error modal
      Navigator.of(context).pop();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _PrintStatusDialog(
          attendee: attendee,
          message: 'Print failed: ${e.toString()}',
          isComplete: true,
          isError: true,
        ),
      );
      
      // Close status modal after delay
      await Future.delayed(const Duration(seconds: 2));
      Navigator.of(context).pop(); // Close status modal
    }
  }


  Future<void> _handleBadgePrinting(Attendee attendee, AnalyticsService analyticsService, String attendeeId) async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final badgeProvider = Provider.of<BadgeProvider>(context, listen: false);
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    
    if (eventProvider.selectedEvent == null) return;
    
    try {
      // Check if direct printing is enabled
      if (settingsProvider.directPrintingEnabled) {
        // Start print timing
        analyticsService.startPrintTiming(attendeeId);
        
        // Auto-print badge
        final success = await badgeProvider.printBadge(
          attendee: attendee,
          eventName: eventProvider.selectedEvent!.name,
          useDirectPrinting: true,
        );
        
        // End print timing
        analyticsService.endPrintTiming(attendeeId);
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.print, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Printing badge for ${attendee.fullName}...'),
                ],
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Failed to print badge'),
                ],
              ),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Text('Badge printing error: ${e.toString()}'),
            ],
          ),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}