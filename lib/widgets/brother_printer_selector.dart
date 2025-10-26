import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/brother_printer.dart';
import '../providers/badge_provider.dart';
import '../screens/brother_printer_setup_screen.dart';

class BrotherPrinterSelector extends StatelessWidget {
  final bool showSetupButton;
  final VoidCallback? onPrinterChanged;

  const BrotherPrinterSelector({
    super.key,
    this.showSetupButton = true,
    this.onPrinterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<BadgeProvider>(
      builder: (context, badgeProvider, child) {
        if (!badgeProvider.isBrotherPrintingEnabled) {
          return _buildInitializeButton(context, badgeProvider);
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.print, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Brother Printer',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (showSetupButton)
                      TextButton.icon(
                        onPressed: () => _openSetupScreen(context),
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('Setup'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildPrinterStatus(context, badgeProvider),
                if (badgeProvider.brotherPrinters.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildPrinterDropdown(context, badgeProvider),
                ],
                if (badgeProvider.hasBrotherConnection) ...[
                  const SizedBox(height: 12),
                  _buildConnectionActions(context, badgeProvider),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInitializeButton(BuildContext context, BadgeProvider badgeProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.print_disabled, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            const Text(
              'Brother Printing Not Initialized',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _initializeBrotherPrinting(badgeProvider),
              icon: const Icon(Icons.power_settings_new),
              label: const Text('Initialize Brother Printing'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrinterStatus(BuildContext context, BadgeProvider badgeProvider) {
    final status = badgeProvider.getBrotherPrinterStatus();
    final isConnected = badgeProvider.hasBrotherConnection;
    
    Color statusColor;
    IconData statusIcon;
    
    if (isConnected) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (badgeProvider.selectedBrotherPrinter != null) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.info_outline;
    }

    return Row(
      children: [
        Icon(statusIcon, color: statusColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (badgeProvider.isDiscoveringBrotherPrinters)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  Widget _buildPrinterDropdown(BuildContext context, BadgeProvider badgeProvider) {
    return DropdownButtonFormField<BrotherPrinter>(
      value: badgeProvider.selectedBrotherPrinter,
      decoration: const InputDecoration(
        labelText: 'Select Printer',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: badgeProvider.brotherPrinters.map((printer) {
        return DropdownMenuItem<BrotherPrinter>(
          value: printer,
          child: Row(
            children: [
              _buildPrinterTypeIcon(printer.connectionType),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      printer.displayName,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${printer.model} • ${_getConnectionTypeDisplay(printer.connectionType)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (printer.isMfiCertified)
                const Icon(Icons.verified, size: 16, color: Colors.blue),
            ],
          ),
        );
      }).toList(),
      onChanged: (printer) => _selectPrinter(badgeProvider, printer),
    );
  }

  Widget _buildConnectionActions(BuildContext context, BadgeProvider badgeProvider) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _testConnection(context, badgeProvider),
            icon: const Icon(Icons.network_check, size: 16),
            label: const Text('Test'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => badgeProvider.disconnectBrotherPrinter(),
            icon: const Icon(Icons.link_off, size: 16),
            label: const Text('Disconnect'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrinterTypeIcon(PrinterConnectionType type) {
    switch (type) {
      case PrinterConnectionType.bluetooth:
      case PrinterConnectionType.bluetoothLE:
        return const Icon(Icons.bluetooth, color: Colors.blue, size: 20);
      case PrinterConnectionType.wifi:
        return const Icon(Icons.wifi, color: Colors.green, size: 20);
      case PrinterConnectionType.usb:
        return const Icon(Icons.usb, color: Colors.orange, size: 20);
      case PrinterConnectionType.mfi:
        return const Icon(Icons.verified, color: Colors.purple, size: 20);
    }
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

  Future<void> _initializeBrotherPrinting(BadgeProvider badgeProvider) async {
    try {
      await badgeProvider.initializeBrotherPrinting();
      await badgeProvider.discoverBrotherPrinters();
    } catch (e) {
      // Error handling is done in the provider
    }
  }

  Future<void> _selectPrinter(BadgeProvider badgeProvider, BrotherPrinter? printer) async {
    if (printer != null) {
      try {
        await badgeProvider.selectBrotherPrinter(printer);
        onPrinterChanged?.call();
      } catch (e) {
        // Error handling is done in the provider
      }
    }
  }

  Future<void> _testConnection(BuildContext context, BadgeProvider badgeProvider) async {
    try {
      final result = await badgeProvider.testBrotherConnection();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result ? 'Connection test passed' : 'Connection test failed'),
            backgroundColor: result ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection test error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _openSetupScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BrotherPrinterSetupScreen(),
      ),
    );
  }
}

/// Compact version of the Brother printer selector for use in smaller spaces
class CompactBrotherPrinterSelector extends StatelessWidget {
  final VoidCallback? onTap;

  const CompactBrotherPrinterSelector({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<BadgeProvider>(
      builder: (context, badgeProvider, child) {
        final isConnected = badgeProvider.hasBrotherConnection;
        final selectedPrinter = badgeProvider.selectedBrotherPrinter;
        
        return InkWell(
          onTap: onTap ?? () => _openSetupScreen(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isConnected ? Icons.print : Icons.print_disabled,
                  color: isConnected ? Colors.green : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  selectedPrinter?.displayName ?? 'No Printer',
                  style: TextStyle(
                    color: isConnected ? Colors.black : Colors.grey,
                    fontWeight: isConnected ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openSetupScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BrotherPrinterSetupScreen(),
      ),
    );
  }
}