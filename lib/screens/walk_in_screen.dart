import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/attendee_provider.dart';
import '../providers/badge_provider.dart';
import '../providers/event_provider.dart';
import '../providers/settings_provider.dart';
import '../models/event.dart';
import '../services/analytics_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../utils/responsive_utils.dart';
import '../widgets/loading_shimmer.dart';

class WalkInScreen extends StatefulWidget {
  final Event event;
  
  const WalkInScreen({Key? key, required this.event}) : super(key: key);

  @override
  State<WalkInScreen> createState() => _WalkInScreenState();
}

class _WalkInScreenState extends State<WalkInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ticketTypeController = TextEditingController();
  
  bool _isVip = false;
  bool _isSubmitting = false;
  
  final List<String> _ticketTypes = [
    'General Admission',
    'VIP',
    'Student',
    'Senior',
    'Group',
    'Complimentary',
    'Press',
    'Staff',
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _ticketTypeController.dispose();
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

          return SingleChildScrollView(
            padding: ResponsiveUtils.getResponsivePaddingInsets(context),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: ResponsiveUtils.getResponsivePaddingInsets(context),
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
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_add,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Walk-In Registration',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Register new attendee for ${eventProvider.selectedEvent!.name}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Form fields
                  Container(
                    padding: EdgeInsets.all(ResponsiveUtils.getResponsivePadding(context) + 4),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // First Name
                        _buildTextField(
                          controller: _firstNameController,
                          label: 'First Name',
                          hint: 'Enter first name',
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'First name is required';
                            }
                            if (value.trim().length < 2) {
                              return 'First name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Last Name
                        _buildTextField(
                          controller: _lastNameController,
                          label: 'Last Name',
                          hint: 'Enter last name',
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Last name is required';
                            }
                            if (value.trim().length < 2) {
                              return 'Last name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Email
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email Address',
                          hint: 'Enter email address',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email is required';
                            }
                            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegex.hasMatch(value.trim())) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Ticket Type
                        _buildDropdownField(),
                        
                        const SizedBox(height: 16),
                        
                        // VIP Toggle
                        _buildVipToggle(),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Register & Check In',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Clear Form Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : _clearForm,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondaryColor,
                        side: BorderSide(color: AppTheme.borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Clear Form',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppTheme.textSecondaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.errorColor),
            ),
            filled: true,
            fillColor: AppTheme.surfaceColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ticket Type',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textColor,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _ticketTypeController.text.isEmpty ? null : _ticketTypeController.text,
          decoration: InputDecoration(
            hintText: 'Select ticket type',
            prefixIcon: Icon(Icons.confirmation_number_outlined, color: AppTheme.textSecondaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: AppTheme.surfaceColor,
          ),
          items: _ticketTypes.map((type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Text(type),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _ticketTypeController.text = value ?? '';
              if (value == 'VIP') {
                _isVip = true;
              }
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a ticket type';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildVipToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.star_outline,
            color: _isVip ? AppTheme.warningColor : AppTheme.textSecondaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VIP Status',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
                Text(
                  'Mark this attendee as VIP',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isVip,
            onChanged: (value) {
              setState(() {
                _isVip = value;
                if (value && _ticketTypeController.text != 'VIP') {
                  _ticketTypeController.text = 'VIP';
                }
              });
            },
            activeColor: AppTheme.warningColor,
          ),
        ],
      ),
    );
  }

  void _clearForm() {
    _firstNameController.clear();
    _lastNameController.clear();
    _emailController.clear();
    _ticketTypeController.clear();
    setState(() {
      _isVip = false;
    });
  }

  Future<void> _handleBadgePrinting(attendee, event, AnalyticsService analyticsService, String attendeeId) async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    if (settingsProvider.directPrintingEnabled) {
      // Auto-print if enabled
      try {
        // Start print timing
        analyticsService.startPrintTiming(attendeeId);
        
        final badgeProvider = Provider.of<BadgeProvider>(context, listen: false);
        await badgeProvider.printBadge(
          attendee: attendee,
          eventName: widget.event.name,
          useDirectPrinting: true,
        );
        
        // End print timing
        analyticsService.endPrintTiming(attendeeId);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Badge printed successfully for ${attendee.fullName}'),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to print badge: ${e.toString()}'),
              backgroundColor: AppTheme.errorColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      // Show manual print option
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${attendee.fullName} registered successfully'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Print Badge',
              textColor: Colors.white,
              onPressed: () async {
                try {
                  // Start print timing for manual print
                  analyticsService.startPrintTiming(attendeeId);
                  
                  final badgeProvider = Provider.of<BadgeProvider>(context, listen: false);
                  await badgeProvider.printBadge(
          attendee: attendee,
          eventName: widget.event.name,
        );
                  
                  // End print timing
                  analyticsService.endPrintTiming(attendeeId);
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Printing badge for ${attendee.fullName}...'),
                        backgroundColor: Colors.blue,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to print badge: ${e.toString()}'),
                        backgroundColor: AppTheme.errorColor,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final analyticsService = AnalyticsService();
    final attendeeId = '${_firstNameController.text.trim()}_${_lastNameController.text.trim()}_${DateTime.now().millisecondsSinceEpoch}';
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    
    // Start analytics timing
    analyticsService.startCheckInProcess(attendeeId);
    analyticsService.startRegistrationTiming(attendeeId);

    try {
      final attendeeProvider = Provider.of<AttendeeProvider>(context, listen: false);
      
      final success = await attendeeProvider.addWalkInAttendee(
        eventId: eventProvider.selectedEvent!.id,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        ticketType: _ticketTypeController.text,
        isVip: _isVip,
      );

      // End registration timing
      analyticsService.endRegistrationTiming(attendeeId);

      if (success) {
        // Provide haptic feedback
        HapticFeedback.lightImpact();
        
        // Get the newly created attendee for badge printing
        final newAttendee = attendeeProvider.lastCreatedAttendee;
        
        // Handle badge printing with analytics
        if (newAttendee != null) {
          await _handleBadgePrinting(newAttendee, eventProvider.selectedEvent!, analyticsService, attendeeId);
        }
        
        // Complete analytics
        analyticsService.completeCheckInProcess(
          attendeeId: attendeeId,
          eventId: eventProvider.selectedEvent!.id,
          checkinType: AppConstants.walkInType,
        );
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('${_firstNameController.text} ${_lastNameController.text} registered and checked in successfully!'),
              ],
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Clear form
        _clearForm();
      } else {
        // Complete analytics even on failure
        analyticsService.completeCheckInProcess(
          attendeeId: attendeeId,
          eventId: eventProvider.selectedEvent!.id,
          checkinType: AppConstants.walkInType,
        );
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text(attendeeProvider.errorMessage ?? 'Failed to register attendee'),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Complete analytics on error
      analyticsService.completeCheckInProcess(
        attendeeId: attendeeId,
        eventId: eventProvider.selectedEvent!.id,
        checkinType: AppConstants.walkInType,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Text('An error occurred: ${e.toString()}'),
            ],
          ),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}