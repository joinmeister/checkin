import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/attendee.dart';
import '../models/event.dart';
import '../providers/badge_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_theme.dart';

class CheckInResultDialog extends StatefulWidget {
  final bool success;
  final Attendee? attendee;
  final Event? event;
  final String? errorMessage;
  final VoidCallback onClose;

  const CheckInResultDialog({
    Key? key,
    required this.success,
    this.attendee,
    this.event,
    this.errorMessage,
    required this.onClose,
  }) : super(key: key);

  @override
  State<CheckInResultDialog> createState() => _CheckInResultDialogState();
}

class _CheckInResultDialogState extends State<CheckInResultDialog> {
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    // Auto-printing is now handled by the calling screen to control modal display
  }

  /// Silent printing for direct printing mode (no user interaction)
  Future<void> _printBadgeSilently() async {
    if (widget.attendee == null || widget.event == null) return;

    try {
      final badgeProvider = Provider.of<BadgeProvider>(context, listen: false);
      print('🔍 CHECK-IN DIALOG: Starting silent badge print for ${widget.attendee!.fullName}');
      print('🔍 CHECK-IN DIALOG: Event: ${widget.event!.name} (${widget.event!.id})');
      print('🔍 CHECK-IN DIALOG: Event regular template ID: ${widget.event!.regularBadgeTemplateId}');
      print('🔍 CHECK-IN DIALOG: Event VIP template ID: ${widget.event!.vipBadgeTemplateId}');
      print('🔍 CHECK-IN DIALOG: Attendee is VIP: ${widget.attendee!.isVip}');

      bool success = false;

      // Try native printing first if enabled and printer is selected
      if (badgeProvider.useNativePrinting && badgeProvider.selectedNativePrinter != null) {
        print('🔍 CHECK-IN DIALOG: Using native printing with ${badgeProvider.selectedNativePrinter!['name']}');
        success = await badgeProvider.printBadgeNatively(
          attendee: widget.attendee!,
          eventName: widget.event?.name,
        );
        
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Badge printed to ${badgeProvider.selectedNativePrinter!['name']}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Fall back to standard direct printing
        print('🔍 CHECK-IN DIALOG: Using standard direct printing');
        success = await badgeProvider.printBadge(
          attendee: widget.attendee!,
          eventName: widget.event?.name,
          useDirectPrinting: true,
        );
      }

      print('🔍 CHECK-IN DIALOG: Silent badge print result: $success');

      // For silent printing, don't show success/failure messages to avoid interrupting the flow
      if (!success) {
        final errorMessage = badgeProvider.errorMessage ?? 'No badge design found';
        print('❌ CHECK-IN DIALOG: Silent badge print failed: $errorMessage');
      }
    } catch (e) {
      print('❌ CHECK-IN DIALOG: Exception during silent badge print: $e');
    }
  }

  /// Show browser print dialog for manual printing
  Future<void> _printBadge() async {
    if (widget.attendee == null || widget.event == null) return;

    setState(() {
      _isPrinting = true;
    });

    try {
      final badgeProvider = Provider.of<BadgeProvider>(context, listen: false);
      print('🔍 CHECK-IN DIALOG: Starting manual badge print for ${widget.attendee!.fullName}');
      
      // Show print preview dialog (browser's default print dialog)
      await badgeProvider.showPrintPreview(
        attendee: widget.attendee!,
        eventName: widget.event?.name,
      );

      print('🔍 CHECK-IN DIALOG: Print preview shown');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print dialog opened for ${widget.attendee!.fullName}'),
            backgroundColor: AppTheme.primaryBlue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ CHECK-IN DIALOG: Exception during manual badge print: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open print dialog: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: widget.success 
                    ? AppTheme.successGreen.withOpacity(0.1)
                    : AppTheme.errorRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.success ? Icons.check_circle : Icons.error,
                size: 48,
                color: widget.success ? AppTheme.successGreen : AppTheme.errorRed,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Title
            Text(
              widget.success ? 'Check-in Successful!' : 'Check-in Failed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: widget.success ? AppTheme.successGreen : AppTheme.errorRed,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 12),
            
            // Content
            if (widget.success && widget.attendee != null) ...[
              _buildSuccessContent(),
            ] else ...[
              _buildErrorContent(),
            ],
            
            const SizedBox(height: 24),
            
            // Print button (only show for successful check-ins)
            if (widget.success && widget.attendee != null && widget.event != null) ...[
              Consumer<SettingsProvider>(
                builder: (context, settingsProvider, child) {
                  // Only show manual print button if auto-print is disabled
                  if (!settingsProvider.directPrintingEnabled) {
                    return Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isPrinting ? null : _printBadge,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: _isPrinting 
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.print),
                            label: Text(
                              _isPrinting ? 'Printing...' : 'Print Badge',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
            
            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.success ? AppTheme.successGreen : AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Continue Scanning',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessContent() {
    return Column(
      children: [
        // Attendee avatar
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            widget.attendee!.isVip ? Icons.star : Icons.person,
            size: 32,
            color: widget.attendee!.isVip ? AppTheme.warningOrange : AppTheme.primaryBlue,
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Attendee name
        Text(
          widget.attendee!.fullName,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryText,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 4),
        
        // Attendee email
        Text(
          widget.attendee!.email,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.secondaryText,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 8),
        
        // Ticket type and VIP status
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.attendee!.ticketType,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
            if (widget.attendee!.isVip) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: 12,
                      color: AppTheme.warningOrange,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'VIP',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warningOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Check-in time
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.successGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: AppTheme.successGreen,
              ),
              const SizedBox(width: 8),
              Text(
                'Checked in at ${_formatTime(DateTime.now())}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.successGreen,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Print button for already checked-in users
        if (widget.attendee!.isCheckedIn) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isPrinting ? null : _printBadge,
              icon: _isPrinting 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print),
              label: Text(_isPrinting ? 'Printing...' : 'Print Badge'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildErrorContent() {
    return Column(
      children: [
        Text(
          widget.errorMessage ?? 'An unknown error occurred',
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.primaryText,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 12),
        
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.errorRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: AppTheme.errorRed,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Please verify the QR code and try again',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.errorRed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour == 0 ? 12 : time.hour > 12 ? time.hour - 12 : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    
    return '$hour:$minute $period';
  }
}