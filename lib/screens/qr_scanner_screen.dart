import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/event.dart';
import '../providers/attendee_provider.dart';
import '../providers/badge_provider.dart';
import '../providers/settings_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/check_in_result_dialog.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

class QRScannerScreen extends StatefulWidget {
  final Event event;

  const QRScannerScreen({
    Key? key,
    required this.event,
  }) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen>
    with AutomaticKeepAliveClientMixin {
  MobileScannerController controller = MobileScannerController();
  bool _isFlashOn = false;
  bool _isProcessing = false;
  String? _lastScannedCode;
  DateTime? _lastScanTime;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
    // CRITICAL FIX: Templates are now loaded globally at app start (like web app)
    // No need to load per-event templates here
  }

  Future<void> _requestCameraPermission() async {
    // Camera permission is handled by the mobile_scanner package
    // Additional permission handling can be added here if needed
  }

  Future<void> _handleScanResult(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    // Prevent duplicate scans within 2 seconds
    final now = DateTime.now();
    if (_lastScannedCode == code && 
        _lastScanTime != null && 
        now.difference(_lastScanTime!).inSeconds < 2) {
      return;
    }

    _lastScannedCode = code;
    _lastScanTime = now;

    setState(() {
      _isProcessing = true;
    });

    // Start analytics timing
    final analyticsService = AnalyticsService();
    final attendeeId = code; // Using QR code as attendee identifier
    analyticsService.startCheckInProcess(attendeeId);
    analyticsService.startScanTiming(attendeeId);

    // Haptic feedback
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    if (settingsProvider.hapticFeedbackEnabled) {
      HapticFeedback.lightImpact();
    }

    try {
      final attendeeProvider = Provider.of<AttendeeProvider>(context, listen: false);
      
      // End scan timing before API call
      analyticsService.endScanTiming(attendeeId);
      
      final success = await attendeeProvider.checkInByQR(code);

      if (mounted) {
        await _showCheckInResult(success, code, attendeeProvider, attendeeId);
      }
    } catch (e) {
      // Complete analytics even on error
      analyticsService.completeCheckInProcess(
        attendeeId: attendeeId,
        eventId: widget.event.id,
        checkinType: AppConstants.qrScanType,
      );
      
      if (mounted) {
        await _showErrorDialog('Check-in failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        
        // Add a short delay before allowing next scan
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    }
  }

  Future<void> _showCheckInResult(bool success, String qrCode, AttendeeProvider attendeeProvider, String attendeeId) async {
    final attendee = attendeeProvider.getAttendeeByQR(qrCode);
    final analyticsService = AnalyticsService();
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    // Start print timing if badge printing is enabled
    if (settingsProvider.badgePrintingEnabled && success) {
      analyticsService.startPrintTiming(attendeeId);
    }
    
    if (settingsProvider.directPrintingEnabled) {
      // For direct printing: perform silent printing and show simple snackbar
      if (success && attendee != null) {
        // Trigger silent printing
        final badgeProvider = Provider.of<BadgeProvider>(context, listen: false);
        badgeProvider.printBadge(
          attendee: attendee,
          eventName: widget.event.name,
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
        final errorMessage = attendeeProvider.checkInError ?? 'Check-in failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.errorRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      // Clear error and complete analytics without showing dialog
      attendeeProvider.clearCheckInError();
      
      // End print timing and complete analytics
      if (settingsProvider.badgePrintingEnabled && success) {
        analyticsService.endPrintTiming(attendeeId);
      }
      
      // Complete the check-in process analytics
      analyticsService.completeCheckInProcess(
        attendeeId: attendeeId,
        eventId: widget.event.id,
        checkinType: AppConstants.qrScanType,
      );
    } else {
      // For non-direct printing: show the full dialog with print button
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => CheckInResultDialog(
          success: success,
          attendee: attendee,
          event: widget.event,
          errorMessage: success ? null : attendeeProvider.checkInError,
          onClose: () {
            Navigator.of(context).pop();
            attendeeProvider.clearCheckInError();
            
            // End print timing and complete analytics
            if (settingsProvider.badgePrintingEnabled && success) {
              analyticsService.endPrintTiming(attendeeId);
            }
            
            // Complete the check-in process analytics
            analyticsService.completeCheckInProcess(
              attendeeId: attendeeId,
              eventId: widget.event.id,
              checkinType: AppConstants.qrScanType,
            );
          },
        ),
      );
    }
  }

  Future<void> _showErrorDialog(String message) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFlash() async {
    await controller.toggleTorch();
    setState(() {
      _isFlashOn = !_isFlashOn;
    });
  }

  Future<void> _flipCamera() async {
    await controller.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // QR Scanner View
          MobileScanner(
            controller: controller,
            onDetect: _handleScanResult,
          ),
          
          // Custom overlay
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              height: MediaQuery.of(context).size.width * 0.7,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.primaryColor,
                  width: 4,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          
          // Top overlay with instructions
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Scan QR Code',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Position the QR code within the frame to check in attendees',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          
          // Bottom overlay with controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
                top: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    label: 'Flash',
                    onPressed: _toggleFlash,
                  ),
                  _buildControlButton(
                    icon: Icons.flip_camera_ios,
                    label: 'Flip',
                    onPressed: _flipCamera,
                  ),
                ],
              ),
            ),
          ),
          
          // Processing overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Processing check-in...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    controller.stop();
    controller.start();
  }
}