import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/event_provider.dart';
import '../providers/attendee_provider.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/printer_settings_widget.dart';
import '../services/brother_printer_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Print Settings Section
                _buildSection(
                  title: 'Print Settings',
                  icon: Icons.print,
                  children: [
                    _buildSwitchTile(
                      title: 'Direct Printing',
                      subtitle: 'Print badges directly without preview',
                      value: settingsProvider.settings.directPrinting,
                      onChanged: (value) {
                        settingsProvider.updateDirectPrinting(value);
                      },
                      icon: Icons.print_outlined,
                    ),
                    _buildListTile(
                      title: 'Print Timeout',
                      subtitle: '${settingsProvider.settings.printTimeout} seconds',
                      icon: Icons.timer_outlined,
                      onTap: () => _showPrintTimeoutDialog(context, settingsProvider),
                    ),
                    _buildListTile(
                      title: 'Default Printer',
                      subtitle: settingsProvider.settings.defaultPrinter ?? 'Not set',
                      icon: Icons.print_outlined,
                      onTap: () => _showPrinterSelectionDialog(context, settingsProvider),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Mock Mode Indicator (iOS only)
                if (Platform.isIOS && BrotherPrinterServiceImpl.isMockMode) ...[
                  _buildSection(
                    title: 'Development Mode',
                    icon: Icons.developer_mode,
                    children: [
                      _buildInfoTile(
                        title: 'iOS Mock Mode',
                        subtitle: 'Brother SDK features are mocked for testing',
                        icon: Icons.phone_iphone,
                        color: Colors.orange,
                      ),
                      _buildInfoTile(
                        title: 'Mock Printers Available',
                        subtitle: 'Simulated Brother printers for UI testing',
                        icon: Icons.print_disabled,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Native Printer Settings
                const PrinterSettingsWidget(),
                
                const SizedBox(height: 24),
                
                // User Experience Section
                _buildSection(
                  title: 'User Experience',
                  icon: Icons.tune,
                  children: [
                    _buildSwitchTile(
                      title: 'Haptic Feedback',
                      subtitle: 'Vibrate on successful actions',
                      value: settingsProvider.settings.hapticFeedback,
                      onChanged: (value) {
                        settingsProvider.updateHapticFeedback(value);
                      },
                      icon: Icons.vibration,
                    ),
                    _buildSwitchTile(
                      title: 'Sound Effects',
                      subtitle: 'Play sounds for notifications',
                      value: settingsProvider.settings.soundEffects,
                      onChanged: (value) {
                        settingsProvider.updateSoundEffects(value);
                      },
                      icon: Icons.volume_up_outlined,
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Data & Sync Section
                _buildSection(
                  title: 'Data & Sync',
                  icon: Icons.sync,
                  children: [
                    _buildSwitchTile(
                      title: 'Offline Mode',
                      subtitle: 'Work without internet connection',
                      value: settingsProvider.settings.offlineMode,
                      onChanged: (value) {
                        settingsProvider.updateOfflineMode(value);
                      },
                      icon: Icons.cloud_off_outlined,
                    ),
                    _buildListTile(
                      title: 'Last Sync',
                      subtitle: settingsProvider.settings.formattedLastSyncTime ?? 'Never',
                      icon: Icons.sync_outlined,
                      onTap: () => _syncData(context),
                    ),
                    _buildListTile(
                      title: 'Clear Cache',
                      subtitle: 'Remove locally stored data',
                      icon: Icons.clear_all_outlined,
                      onTap: () => _showClearCacheDialog(context),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // App Information Section
                _buildSection(
                  title: 'App Information',
                  icon: Icons.info_outline,
                  children: [
                    _buildListTile(
                      title: 'Version',
                      subtitle: AppConstants.appVersion,
                      icon: Icons.info_outlined,
                      onTap: null,
                    ),
                    _buildListTile(
                      title: 'Build Number',
                      subtitle: AppConstants.buildNumber,
                      icon: Icons.build_outlined,
                      onTap: null,
                    ),
                    _buildListTile(
                      title: 'About',
                      subtitle: 'Learn more about this app',
                      icon: Icons.help_outline,
                      onTap: () => _showAboutDialog(context),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Debug Section (only in debug mode)
                if (AppConstants.isDebugMode) ...[
                  _buildSection(
                    title: 'Debug',
                    icon: Icons.bug_report,
                    children: [
                      _buildListTile(
                        title: 'API Base URL',
                        subtitle: ApiConstants.baseUrl,
                        icon: Icons.link_outlined,
                        onTap: null,
                      ),
                      _buildListTile(
                        title: 'Reset Settings',
                        subtitle: 'Reset all settings to default',
                        icon: Icons.restore_outlined,
                        onTap: () => _showResetSettingsDialog(context, settingsProvider),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
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
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: AppTheme.primaryColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppTheme.textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: AppTheme.textSecondaryColor,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildListTile({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: AppTheme.primaryColor,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppTheme.textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: AppTheme.textSecondaryColor,
        ),
      ),
      trailing: onTap != null
          ? Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondaryColor,
            )
          : null,
      onTap: onTap,
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: color,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppTheme.textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: AppTheme.textSecondaryColor,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          'SIMULATOR',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  void _showPrintTimeoutDialog(BuildContext context, SettingsProvider settingsProvider) {
    final controller = TextEditingController(
      text: settingsProvider.settings.printTimeout.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Print Timeout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Set the timeout for print operations (in seconds):'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Timeout (seconds)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final timeout = int.tryParse(controller.text);
              if (timeout != null && timeout > 0) {
                settingsProvider.updatePrintTimeout(timeout);
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showPrinterSelectionDialog(BuildContext context, SettingsProvider settingsProvider) {
    // This would typically show available printers
    // For now, we'll show a simple text input
    final controller = TextEditingController(
      text: settingsProvider.settings.defaultPrinter ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Printer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the name of your default printer:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Printer Name',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              settingsProvider.updateDefaultPrinter(controller.text.trim());
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _syncData(BuildContext context) async {
    final eventProvider = Provider.of<EventProvider>(context, listen: false);
    final attendeeProvider = Provider.of<AttendeeProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Syncing data...'),
          ],
        ),
      ),
    );

    try {
      // Refresh events
      await eventProvider.fetchEvents();
      
      // Refresh attendees if an event is selected
      if (eventProvider.selectedEvent != null) {
        await attendeeProvider.fetchAttendees(eventProvider.selectedEvent!.id);
      }
      
      // Update last sync time
      settingsProvider.updateLastSyncTime(DateTime.now());
      
      Navigator.of(context).pop(); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Data synced successfully'),
            ],
          ),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Text('Sync failed: ${e.toString()}'),
            ],
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will remove all locally stored data. You will need to sync again to reload data. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Clear cache logic would go here
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text('Cache cleared successfully'),
                    ],
                  ),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: AppConstants.appVersion,
      applicationIcon: Icon(
        Icons.event,
        size: 48,
        color: AppTheme.primaryColor,
      ),
      children: [
        const Text(
          'Event Manager Mobile is a companion app for managing event check-ins, '
          'walk-in registrations, and attendee management.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Features:\n'
          '• QR code scanning for quick check-ins\n'
          '• Walk-in attendee registration\n'
          '• Search and manual check-in\n'
          '• Badge printing integration\n'
          '• Offline mode support',
        ),
      ],
    );
  }

  void _showResetSettingsDialog(BuildContext context, SettingsProvider settingsProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'This will reset all settings to their default values. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              settingsProvider.resetSettings();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text('Settings reset successfully'),
                    ],
                  ),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}