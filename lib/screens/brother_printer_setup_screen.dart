import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/brother_printer.dart';
import '../providers/badge_provider.dart';
import '../services/connection_health_monitor.dart';
import '../services/print_queue_manager.dart';

class BrotherPrinterSetupScreen extends StatefulWidget {
  const BrotherPrinterSetupScreen({super.key});

  @override
  State<BrotherPrinterSetupScreen> createState() => _BrotherPrinterSetupScreenState();
}

class _BrotherPrinterSetupScreenState extends State<BrotherPrinterSetupScreen> {
  @override
  void initState() {
    super.initState();
    _initializeBrotherPrinting();
  }

  Future<void> _initializeBrotherPrinting() async {
    final badgeProvider = Provider.of<BadgeProvider>(context, listen: false);
    
    if (!badgeProvider.isBrotherPrintingEnabled) {
      await badgeProvider.initializeBrotherPrinting();
    }
    
    // Start discovery
    await badgeProvider.discoverBrotherPrinters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brother Printer Setup'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshPrinters(),
            tooltip: 'Refresh Printers',
          ),
        ],
      ),
      body: Consumer<BadgeProvider>(
        builder: (context, badgeProvider, child) {
          if (!badgeProvider.isBrotherPrintingEnabled) {
            return _buildInitializingView();
          }

          return Column(
            children: [
              _buildStatusCard(badgeProvider),
              _buildQueueStatusCard(badgeProvider),
              Expanded(
                child: _buildPrinterList(badgeProvider),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _testPrinting(),
        child: const Icon(Icons.print),
        tooltip: 'Test Print',
      ),
    );
  }

  Widget _buildInitializingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Initializing Brother Printer Services...',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BadgeProvider badgeProvider) {
    final status = badgeProvider.getBrotherPrinterStatus();
    final isConnected = badgeProvider.hasBrotherConnection;
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isConnected ? Icons.check_circle : Icons.error_outline,
                  color: isConnected ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Printer Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(status),
            if (badgeProvider.selectedBrotherPrinter != null) ...[
              const SizedBox(height: 8),
              Text(
                'Selected: ${badgeProvider.selectedBrotherPrinter!.displayName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Type: ${badgeProvider.selectedBrotherPrinter!.connectionType.toString().split('.').last}',
              ),
              if (badgeProvider.selectedBrotherPrinter!.isMfiCertified)
                const Row(
                  children: [
                    Icon(Icons.verified, size: 16, color: Colors.blue),
                    SizedBox(width: 4),
                    Text('MFi Certified'),
                  ],
                ),
            ],
            if (isConnected) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _testConnection(badgeProvider),
                    icon: const Icon(Icons.network_check, size: 16),
                    label: const Text('Test Connection'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => badgeProvider.disconnectBrotherPrinter(),
                    icon: const Icon(Icons.link_off, size: 16),
                    label: const Text('Disconnect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQueueStatusCard(BadgeProvider badgeProvider) {
    final queueStats = badgeProvider.getQueueStatistics();
    
    if (queueStats == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.queue, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Print Queue',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQueueStat('Pending', queueStats.pendingJobs, Colors.orange),
                _buildQueueStat('Processing', queueStats.processingJobs, Colors.blue),
                _buildQueueStat('Completed', queueStats.completedJobs, Colors.green),
              ],
            ),
            if (queueStats.averageProcessingTime > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Avg. Processing Time: ${queueStats.averageProcessingTime.toStringAsFixed(1)}ms',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQueueStat(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPrinterList(BadgeProvider badgeProvider) {
    if (badgeProvider.isDiscoveringBrotherPrinters) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Discovering Brother Printers...'),
          ],
        ),
      );
    }

    if (badgeProvider.brotherPrinters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.print_disabled,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Brother Printers Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Make sure your Brother printer is:\n• Powered on\n• Connected to the same network\n• Bluetooth enabled (for BT printers)',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _refreshPrinters(),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: badgeProvider.brotherPrinters.length,
      itemBuilder: (context, index) {
        final printer = badgeProvider.brotherPrinters[index];
        final isSelected = badgeProvider.selectedBrotherPrinter?.id == printer.id;
        final isConnected = isSelected && badgeProvider.hasBrotherConnection;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: _buildPrinterIcon(printer),
            title: Text(
              printer.displayName,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${printer.model} • ${_getConnectionTypeDisplay(printer.connectionType)}'),
                if (printer.bluetoothAddress != null)
                  Text('Bluetooth: ${printer.bluetoothAddress}', style: const TextStyle(fontSize: 12)),
                if (printer.ipAddress != null)
                  Text('IP: ${printer.ipAddress}', style: const TextStyle(fontSize: 12)),
                _buildPrinterStatus(printer, isSelected, isConnected),
              ],
            ),
            trailing: isSelected
                ? (isConnected
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.radio_button_checked, color: Colors.blue))
                : const Icon(Icons.radio_button_unchecked),
            onTap: () => _selectPrinter(badgeProvider, printer),
          ),
        );
      },
    );
  }

  Widget _buildPrinterIcon(BrotherPrinter printer) {
    IconData iconData;
    Color iconColor;

    switch (printer.connectionType) {
      case PrinterConnectionType.bluetooth:
      case PrinterConnectionType.bluetoothLE:
        iconData = Icons.bluetooth;
        iconColor = Colors.blue;
        break;
      case PrinterConnectionType.wifi:
        iconData = Icons.wifi;
        iconColor = Colors.green;
        break;
      case PrinterConnectionType.usb:
        iconData = Icons.usb;
        iconColor = Colors.orange;
        break;
      case PrinterConnectionType.mfi:
        iconData = Icons.verified;
        iconColor = Colors.purple;
        break;
    }

    return Stack(
      children: [
        Icon(iconData, color: iconColor, size: 32),
        if (printer.isMfiCertified)
          const Positioned(
            right: 0,
            bottom: 0,
            child: Icon(Icons.verified, color: Colors.blue, size: 16),
          ),
      ],
    );
  }

  Widget _buildPrinterStatus(BrotherPrinter printer, bool isSelected, bool isConnected) {
    if (!isSelected) {
      return Text(
        printer.status.toString().split('.').last,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    Color statusColor;
    String statusText;

    if (isConnected) {
      statusColor = Colors.green;
      statusText = 'Connected';
    } else {
      switch (printer.status) {
        case PrinterStatus.connecting:
          statusColor = Colors.orange;
          statusText = 'Connecting...';
          break;
        case PrinterStatus.error:
          statusColor = Colors.red;
          statusText = 'Error';
          break;
        case PrinterStatus.lowBattery:
          statusColor = Colors.orange;
          statusText = 'Low Battery';
          break;
        case PrinterStatus.outOfLabels:
          statusColor = Colors.red;
          statusText = 'Out of Labels';
          break;
        default:
          statusColor = Colors.grey;
          statusText = 'Disconnected';
      }
    }

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          statusText,
          style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _getConnectionTypeDisplay(PrinterConnectionType type) {
    switch (type) {
      case PrinterConnectionType.bluetooth:
        return 'Bluetooth';
      case PrinterConnectionType.bluetoothLE:
        return 'Bluetooth LE';
      case PrinterConnectionType.wifi:
        return 'WiFi';
      case PrinterConnectionType.usb:
        return 'USB';
      case PrinterConnectionType.mfi:
        return 'MFi';
    }
  }

  Future<void> _selectPrinter(BadgeProvider badgeProvider, BrotherPrinter printer) async {
    try {
      await badgeProvider.selectBrotherPrinter(printer);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected ${printer.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select printer: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshPrinters() async {
    final badgeProvider = Provider.of<BadgeProvider>(context, listen: false);
    await badgeProvider.discoverBrotherPrinters();
  }

  Future<void> _testConnection(BadgeProvider badgeProvider) async {
    try {
      final result = await badgeProvider.testBrotherConnection();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result ? 'Connection test passed' : 'Connection test failed'),
            backgroundColor: result ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection test error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testPrinting() async {
    final badgeProvider = Provider.of<BadgeProvider>(context, listen: false);
    
    if (!badgeProvider.hasBrotherConnection) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No Brother printer connected'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show test print dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test Print'),
        content: const Text('This will print a test label to verify your Brother printer is working correctly.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performTestPrint(badgeProvider);
            },
            child: const Text('Print Test'),
          ),
        ],
      ),
    );
  }

  Future<void> _performTestPrint(BadgeProvider badgeProvider) async {
    try {
      // Create a test attendee
      final testAttendee = Attendee(
        id: 'test_${DateTime.now().millisecondsSinceEpoch}',
        eventId: 'test_event',
        firstName: 'Test',
        lastName: 'User',
        email: 'test@example.com',
        ticketType: 'Test Ticket',
        isVip: false,
        isCheckedIn: true,
        qrCode: 'TEST_QR_CODE_${DateTime.now().millisecondsSinceEpoch}',
        badgeGenerated: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final success = await badgeProvider.printBadge(
        attendee: testAttendee,
        eventName: 'Test Event',
        useBrotherPrinter: true,
        priority: JobPriority.high,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Test print sent successfully' : 'Test print failed'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test print error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}