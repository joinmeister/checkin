import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/badge_provider.dart';
import '../services/native_printer_service.dart';
import '../utils/app_theme.dart';

class PrinterSettingsWidget extends StatefulWidget {
  const PrinterSettingsWidget({Key? key}) : super(key: key);

  @override
  State<PrinterSettingsWidget> createState() => _PrinterSettingsWidgetState();
}

class _PrinterSettingsWidgetState extends State<PrinterSettingsWidget> {
  @override
  void initState() {
    super.initState();
    _initializePrinting();
  }

  Future<void> _initializePrinting() async {
    final badgeProvider = Provider.of<BadgeProvider>(context, listen: false);
    await badgeProvider.initializeNativePrinting();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BadgeProvider>(
      builder: (context, badgeProvider, child) {
        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.print, color: AppTheme.primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      'Printer Settings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Native printing toggle
                SwitchListTile(
                  title: const Text('Use Native Printing'),
                  subtitle: const Text('Enable direct printing without dialogs'),
                  value: badgeProvider.useNativePrinting,
                  onChanged: (value) {
                    badgeProvider.setUseNativePrinting(value);
                    if (value && badgeProvider.discoveredPrinters.isEmpty) {
                      _discoverPrinters();
                    }
                  },
                  activeColor: AppTheme.primaryBlue,
                ),
                
                if (badgeProvider.useNativePrinting) ...[
                  const Divider(),
                  
                  // Discover printers button
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: badgeProvider.isDiscoveringPrinters 
                              ? null 
                              : _discoverPrinters,
                          icon: badgeProvider.isDiscoveringPrinters
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.search),
                          label: Text(
                            badgeProvider.isDiscoveringPrinters
                                ? 'Discovering...'
                                : 'Discover Printers',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Discovered printers list
                  if (badgeProvider.discoveredPrinters.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Available Printers (${badgeProvider.discoveredPrinters.length})',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Use ListView.builder with shrinkWrap to properly handle constraints
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: badgeProvider.discoveredPrinters.length,
                          itemBuilder: (context, index) {
                        final printer = badgeProvider.discoveredPrinters[index];
                        final isSelected = badgeProvider.selectedNativePrinter?['id'] == printer['id'];
                        final capabilities = printer['capabilities'] as List<dynamic>? ?? [];
                        final status = printer['status'] ?? 'unknown';
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: isSelected ? AppTheme.primaryBlue.withOpacity(0.1) : null,
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: _getPrinterTypeColor(printer['type'] ?? 'unknown'),
                              child: Icon(
                                _getPrinterTypeIcon(printer['type'] ?? 'unknown'),
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              printer['name'] ?? 'Unknown Printer',
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              '${_getPrinterTypeLabel(printer['type'] ?? 'unknown')} • ${_getConnectionLabel(printer['connectionType'] ?? 'unknown')}',
                              style: TextStyle(
                                color: _getConnectionColor(printer['connectionType'] ?? 'unknown'),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) 
                                  Icon(Icons.check_circle, color: AppTheme.primaryBlue, size: 20),
                                IconButton(
                                  icon: Icon(Icons.print, size: 18),
                                  onPressed: () => _testPrint(context, badgeProvider, printer),
                                  tooltip: 'Test Print',
                                  constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                              ],
                            ),
                            onExpansionChanged: (expanded) {
                              if (expanded) {
                                badgeProvider.selectNativePrinter(printer);
                              }
                            },
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (printer['model'] != null)
                                      _buildDetailRow('Model', printer['model']),
                                    if (printer['url'] != null)
                                      _buildDetailRow('URL', printer['url']),
                                    if (printer['location'] != null)
                                      _buildDetailRow('Location', printer['location']),
                                    if (printer['ipAddress'] != null)
                                      _buildDetailRow('IP Address', printer['ipAddress']),
                                    _buildDetailRow('Status', status),
                                    _buildDetailRow('Default', printer['isDefault'] == true ? 'Yes' : 'No'),
                                    if (capabilities.isNotEmpty) ...[
                                      SizedBox(height: 8),
                                      Text(
                                        'Capabilities:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: capabilities.map((capability) {
                                          return Chip(
                                            label: Text(
                                              capability.toString(),
                                              style: TextStyle(fontSize: 11),
                                            ),
                                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                    SizedBox(height: 12),
                                    // Fix overflow by stacking buttons vertically on small screens
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        if (constraints.maxWidth < 300) {
                                          // Stack buttons vertically for small screens
                                          return Column(
                                            children: [
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton.icon(
                                                  onPressed: () {
                                                    badgeProvider.selectNativePrinter(printer);
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('Selected ${printer['name'] ?? 'Unknown Printer'}'),
                                                        backgroundColor: AppTheme.primaryBlue,
                                                        duration: const Duration(seconds: 2),
                                                      ),
                                                    );
                                                  },
                                                  icon: Icon(Icons.check, size: 16),
                                                  label: Text('Select Printer'),
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton.icon(
                                                  onPressed: () => _testPrint(context, badgeProvider, printer),
                                                  icon: Icon(Icons.print, size: 16),
                                                  label: Text('Test Print'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        } else {
                                          // Keep horizontal layout for larger screens
                                          return Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () {
                                                    badgeProvider.selectNativePrinter(printer);
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('Selected ${printer['name'] ?? 'Unknown Printer'}'),
                                                        backgroundColor: AppTheme.primaryBlue,
                                                        duration: const Duration(seconds: 2),
                                                      ),
                                                    );
                                                  },
                                                  icon: Icon(Icons.check, size: 16),
                                                  label: Text('Select Printer'),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () => _testPrint(context, badgeProvider, printer),
                                                  icon: Icon(Icons.print, size: 16),
                                                  label: Text('Test Print'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green,
                                                    foregroundColor: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                      ],
                    )
                  else if (!badgeProvider.isDiscoveringPrinters)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No printers discovered. Tap "Discover Printers" to search for available printers.',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Selected printer info
                  if (badgeProvider.selectedNativePrinter != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: AppTheme.primaryBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected Printer',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryBlue,
                                  ),
                                ),
                                Text(badgeProvider.selectedNativePrinter!['name'] ?? 'Unknown Printer'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                
                // Error message
                if (badgeProvider.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            badgeProvider.errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _discoverPrinters() async {
    final badgeProvider = Provider.of<BadgeProvider>(context, listen: false);
    await badgeProvider.discoverNativePrinters();
  }

  Color _getPrinterTypeColor(String type) {
    switch (type) {
      case 'brother':
        return AppTheme.primaryBlue;
      case 'system':
        return Colors.green;
      case 'thermal':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getPrinterTypeIcon(String type) {
    switch (type) {
      case 'brother':
        return Icons.label;
      case 'system':
        return Icons.print;
      case 'thermal':
        return Icons.receipt;
      default:
        return Icons.print;
    }
  }

  String _getPrinterTypeLabel(String type) {
    switch (type) {
      case 'brother':
        return 'Brother Label Printer';
      case 'system':
        return 'System Printer (AirPrint/Standard)';
      case 'thermal':
        return 'Thermal Printer';
      default:
        return 'Unknown Printer';
    }
  }

  String _getConnectionLabel(String connectionType) {
    switch (connectionType) {
      case 'bluetooth':
        return 'Bluetooth';
      case 'wifi':
        return 'Wi-Fi';
      case 'usb':
        return 'USB';
      case 'system':
        return 'System';
      case 'browser':
        return 'Browser';
      case 'virtual':
        return 'Virtual';
      case 'fax':
        return 'Fax';
      default:
        return 'Unknown';
    }
  }

  Color _getConnectionColor(String connectionType) {
    switch (connectionType) {
      case 'bluetooth':
        return Colors.blue;
      case 'wifi':
        return Colors.green;
      case 'usb':
        return Colors.orange;
      case 'system':
        return Colors.purple;
      case 'browser':
        return Colors.indigo;
      case 'virtual':
        return Colors.teal;
      case 'fax':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
      case 'ready':
      case 'idle':
        return Colors.green;
      case 'printing':
        return Colors.blue;
      case 'error':
      case 'offline':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testPrint(BuildContext context, BadgeProvider badgeProvider, Map<String, dynamic> printer) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Sending test print...'),
            ],
          ),
        ),
      );

      // Perform test print
      final success = await badgeProvider.testPrint(printerId: printer['id']);
      
      Navigator.of(context).pop(); // Close loading dialog
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test print sent to ${printer['name']}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test print failed for ${printer['name']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test print failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}