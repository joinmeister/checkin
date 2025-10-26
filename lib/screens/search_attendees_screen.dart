import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendee_provider.dart';
import '../providers/badge_provider.dart';
import '../providers/event_provider.dart';
import '../providers/settings_provider.dart';
import '../models/attendee.dart';
import '../models/event.dart';
import '../services/analytics_service.dart';
import '../utils/constants.dart';
import '../utils/app_theme.dart';
import '../widgets/check_in_result_dialog.dart';

class SearchAttendeesScreen extends StatefulWidget {
  final Event event;
  
  const SearchAttendeesScreen({super.key, required this.event});

  @override
  State<SearchAttendeesScreen> createState() => _SearchAttendeesScreenState();
}

class _SearchAttendeesScreenState extends State<SearchAttendeesScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAttendees();
    _loadBadgeTemplates();
  }

  Future<void> _loadAttendees() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final attendeeProvider = Provider.of<AttendeeProvider>(context, listen: false);
      await attendeeProvider.loadAttendees(widget.event.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading attendees: $e')),
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

  Future<void> _loadBadgeTemplates() async {
    try {
      final badgeProvider = Provider.of<BadgeProvider>(context, listen: false);
      // CRITICAL FIX: Templates are now loaded globally at app start (like web app)
      // No need to load per-event templates here
      print('🔍 SEARCH SCREEN: Templates already loaded globally: ${badgeProvider.templates.length}');
    } catch (e) {
      print('Error loading badge templates: $e');
      // Don't show error to user, this is a silent fallback
    }
  }

  List<Attendee> _getFilteredAttendees(List<Attendee> attendees) {
    final query = _searchController.text;
    if (query.isEmpty) {
      return attendees;
    } else {
      return attendees
          .where((attendee) =>
              attendee.firstName.toLowerCase().contains(query.toLowerCase()) ||
              attendee.lastName.toLowerCase().contains(query.toLowerCase()) ||
              attendee.email.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

  Future<void> _printLabel(Attendee attendee) async {
    try {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      final badgeProvider = Provider.of<BadgeProvider>(context, listen: false);
      
      // CRITICAL FIX: Templates are now loaded globally at app start (like web app)
      // Template selection happens inside printBadge() method
      print('🔍 SEARCH SCREEN: Using globally loaded templates: ${badgeProvider.templates.length}');
      print('🔍 SEARCH SCREEN: Starting badge print for ${attendee.fullName} (VIP: ${attendee.isVip})');

      // Check if direct printing is enabled
      if (settingsProvider.directPrintingEnabled) {
        // Direct printing - print immediately
        await badgeProvider.printBadge(
          attendee: attendee,
          eventName: widget.event.name,
          useDirectPrinting: true,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Printing badge for ${attendee.firstName} ${attendee.lastName}...'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Show preview dialog with save option
        await _showPrintPreviewDialog(attendee);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error printing badge: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showPrintPreviewDialog(Attendee attendee) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Print Badge'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Print badge for ${attendee.firstName} ${attendee.lastName}?'),
              const SizedBox(height: 16),
              if (attendee.isVip)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'VIP Badge',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[800],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.preview),
              label: const Text('Preview'),
              onPressed: () async {
                Navigator.of(context).pop();
                final badgeProvider = Provider.of<BadgeProvider>(context, listen: false);
                await badgeProvider.showPrintPreview(
                  attendee: attendee,
                  eventName: widget.event.name,
                );
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Save'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _saveBadgeToDownloads(attendee);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveBadgeToDownloads(Attendee attendee) async {
    try {
      final badgeProvider = Provider.of<BadgeProvider>(context, listen: false);
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Saving badge...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final filePath = await badgeProvider.saveBadgeToDownloads(
        attendee: attendee,
        eventName: widget.event.name,
      );

      if (mounted) {
        if (filePath != null) {
          // Check if it's a web download
          if (filePath.startsWith('web_download_')) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Badge download started: ${filePath.split('_').last}'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Badge saved to Downloads: ${filePath.split('/').last}'),
                backgroundColor: Colors.green,
                action: SnackBarAction(
                  label: 'Open',
                  onPressed: () {
                    // Could add functionality to open file manager here
                  },
                ),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save badge: ${badgeProvider.errorMessage ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving badge: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkInAttendee(Attendee attendee) async {
    final analyticsService = AnalyticsService();
    final attendeeId = attendee.id.toString();
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Checking in ${attendee.firstName} ${attendee.lastName}...'),
          ],
        ),
      ),
    );
    
    // Start analytics timing
    analyticsService.startCheckInTiming(attendeeId);
    
    try {
      final attendeeProvider = Provider.of<AttendeeProvider>(context, listen: false);
      final success = await attendeeProvider.checkInAttendeeById(attendee.id);
      
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      // End analytics timing
      analyticsService.endCheckInTiming(attendeeId);
      
      // Complete analytics
      await analyticsService.completeCheckIn(
        attendeeId: attendeeId,
        eventId: attendeeProvider.selectedEventId ?? '',
        checkInType: CheckInType.manual.name,
      );

      if (mounted) {
        final eventProvider = Provider.of<EventProvider>(context, listen: false);
        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
        
        if (settingsProvider.directPrintingEnabled) {
          // For direct printing: perform silent printing and show simple snackbar
          if (success && attendee != null && eventProvider.selectedEvent != null) {
            // Trigger silent printing
            final badgeProvider = Provider.of<BadgeProvider>(context, listen: false);
            badgeProvider.printBadge(
              attendee: attendee,
              eventName: eventProvider.selectedEvent?.name,
              useDirectPrinting: true,
            );
            
            // Show simple success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${attendee.firstName} ${attendee.lastName} checked in successfully'),
                backgroundColor: AppTheme.successGreen,
                duration: const Duration(seconds: 2),
              ),
            );
          } else {
            // Show error message for failed check-in
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to check in ${attendee.firstName} ${attendee.lastName}'),
                backgroundColor: AppTheme.errorRed,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } else {
          // For non-direct printing: show the full dialog with print button
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => CheckInResultDialog(
              success: success,
              attendee: success ? attendee : null,
              event: eventProvider.selectedEvent,
              errorMessage: success ? null : 'Failed to check in ${attendee.firstName} ${attendee.lastName}',
              onClose: () {
                Navigator.of(context).pop();
              },
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking in attendee: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AttendeeProvider>(
        builder: (context, attendeeProvider, child) {
          // Get filtered attendees from provider instead of local state
          final filteredAttendees = _getFilteredAttendees(attendeeProvider.attendees);
          
          if (attendeeProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search attendees',
                      hintText: 'Enter name or email',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    ),
                    onChanged: (value) {
                      setState(() {
                        // Just trigger rebuild, filtering is done in _getFilteredAttendees
                      });
                    },
                  ),
                ),
              ),
              filteredAttendees.isEmpty
                  ? SliverFillRemaining(
                      child: const Center(
                        child: Text(
                          'No attendees found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final attendee = filteredAttendees[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8.0),
                              child: ListTile(
                                title: Text('${attendee.firstName} ${attendee.lastName}'),
                                subtitle: Text(attendee.email),
                                trailing: attendee.isCheckedIn
                                    ? IconButton(
                                        icon: const Icon(Icons.print),
                                        onPressed: () => _printLabel(attendee),
                                        tooltip: 'Print Label',
                                      )
                                    : IconButton(
                                        icon: const Icon(Icons.check_circle_outline),
                                        onPressed: () => _checkInAttendee(attendee),
                                        tooltip: 'Check In',
                                      ),
                                leading: attendee.isVip
                                    ? const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                      )
                                    : const Icon(Icons.person),
                              ),
                            );
                          },
                          childCount: filteredAttendees.length,
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}