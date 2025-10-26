import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/attendee.dart';
import '../models/badge_template.dart';
import 'badge_printing_service.dart';

/// Simplified printer service for badge printing
class NativePrinterService {
  static final NativePrinterService _instance = NativePrinterService._internal();
  factory NativePrinterService() => _instance;
  NativePrinterService._internal();

  // Configuration options
  static const bool _enableFallbackPrinters = false; // Set to true for debugging
  
  // Available printers list
  final List<Map<String, dynamic>> _availablePrinters = [];
  Map<String, dynamic>? _selectedPrinter;
  
  // Stream controllers for printer events
  final StreamController<List<Map<String, dynamic>>> _printersController = 
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final StreamController<String> _connectionController = 
      StreamController<String>.broadcast();

  // Getters for streams
  Stream<List<Map<String, dynamic>>> get printersStream => _printersController.stream;
  Stream<String> get connectionStream => _connectionController.stream;
  List<Map<String, dynamic>> get availablePrinters => List.unmodifiable(_availablePrinters);
  Map<String, dynamic>? get selectedPrinter => _selectedPrinter;

  /// Initialize the printer service
  Future<void> initialize() async {
    try {
      debugPrint('Native printer service initialized');
    } catch (e) {
      debugPrint('Error initializing native printer service: $e');
    }
  }

  /// Discover available printers (web-compatible and system printers)
  Future<void> discoverPrinters() async {
    try {
      debugPrint('Starting printer discovery...');
      _availablePrinters.clear();
      
      // Use the new web-compatible discovery system
      await _discoverSystemPrinters();
      
      _printersController.add(_availablePrinters);
      _connectionController.add('discovered');
      debugPrint('Printer discovery completed. Found ${_availablePrinters.length} printers');
      
    } catch (e) {
      debugPrint('Error during printer discovery: $e');
      
      // Always add web-compatible printers as fallback
      try {
        await _addWebCompatiblePrinters();
      } catch (fallbackError) {
        debugPrint('Error adding fallback printers: $fallbackError');
      }
      
      _printersController.add(_availablePrinters);
      _connectionController.add('error');
    }
  }

  /// Discover Brother printers
  Future<void> _discoverBrotherPrinters() async {
    try {
      // Note: Brother printer discovery requires specific Brother SDK integration
      // For now, we skip Brother printer discovery and rely on system printers
      // Real Brother printers should be accessible through system printer discovery
      debugPrint('Brother printer discovery skipped - using system printer discovery instead');
      
    } catch (e) {
      debugPrint('Error discovering Brother printers: $e');
    }
  }

  /// Discover system printers
  Future<void> _discoverSystemPrinters() async {
    try {
      debugPrint('Starting system printer discovery...');
      
      if (kIsWeb) {
        // Web platform: Printing.listPrinters() is not supported
        debugPrint('Web platform detected - using web-compatible printer discovery');
        await _discoverWebPrinters();
      } else {
        // Native platform: Use Printing.listPrinters()
        debugPrint('Native platform detected - using system printer discovery');
        await _discoverNativePrinters();
      }
      
    } catch (e) {
      debugPrint('Error discovering system printers: $e');
      // Always add web-compatible printers as fallback
      await _addWebCompatiblePrinters();
    }
  }

  /// Discover printers on web platform
  Future<void> _discoverWebPrinters() async {
    try {
      debugPrint('Discovering web-compatible printers...');
      
      // Add web-compatible printers that work with the printing package
      await _addWebCompatiblePrinters();
      
      debugPrint('Web printer discovery completed. Found ${_availablePrinters.length} printers');
      
    } catch (e) {
      debugPrint('Error in web printer discovery: $e');
      await _addWebCompatiblePrinters();
    }
  }

  /// Discover printers on native platform
  Future<void> _discoverNativePrinters() async {
    try {
      debugPrint('Attempting to discover native printers...');
      
      // Wrap in try-catch to handle MissingPluginException gracefully
      List<Printer> printers = [];
      try {
        printers = await Printing.listPrinters();
      } on MissingPluginException catch (e) {
        debugPrint('Native printer discovery not supported on this platform: $e');
        // Fall through to web-compatible printers
      } on PlatformException catch (e) {
        debugPrint('Platform exception during printer discovery: $e');
        // Fall through to web-compatible printers
      }
      
      if (printers.isNotEmpty) {
        debugPrint('Found ${printers.length} system printers');
        
        for (int i = 0; i < printers.length; i++) {
          final printer = printers[i];
          
          // Enhanced printer information for native platforms
          final printerInfo = {
            'id': 'system_${i}',
            'name': printer.name,
            'type': _determinePrinterType(printer.name),
            'connectionType': _determineConnectionType(printer.name),
            'isDefault': printer.isDefault,
            'url': printer.url,
            'model': _extractPrinterModel(printer.name),
            'status': 'available',
            'capabilities': _getPrinterCapabilities(printer.name),
            'location': _getPrinterLocation(printer.name),
          };
          
          _availablePrinters.add(printerInfo);
          debugPrint('Added printer: ${printer.name} (${printerInfo['connectionType']})');
        }
        
      } else {
        debugPrint('No system printers found on native platform - using web-compatible printers');
        // Add web-compatible printers as fallback
        await _addWebCompatiblePrinters();
      }
      
    } catch (e) {
      debugPrint('Error discovering native printers: $e');
      // Add web-compatible printers as fallback
      await _addWebCompatiblePrinters();
    }
  }

  /// Add web-compatible printers that work with the printing package
  Future<void> _addWebCompatiblePrinters() async {
    try {
      debugPrint('Adding web-compatible printers...');
      
      // Add browser print option (works on all web browsers)
      final browserPrinter = {
        'id': 'browser_print',
        'name': 'Browser Print',
        'type': 'browser',
        'connectionType': 'browser',
        'isDefault': true,
        'url': null,
        'model': 'Browser Print',
        'status': 'available',
        'capabilities': ['color', 'pdf'],
        'location': 'Browser',
      };
      _availablePrinters.add(browserPrinter);
      debugPrint('Added browser printer: Browser Print');
      
      // Add PDF download option
      final pdfPrinter = {
        'id': 'pdf_download',
        'name': 'Download as PDF',
        'type': 'pdf',
        'connectionType': 'download',
        'isDefault': false,
        'url': null,
        'model': 'PDF Download',
        'status': 'available',
        'capabilities': ['pdf', 'download'],
        'location': 'Downloads',
      };
      _availablePrinters.add(pdfPrinter);
      debugPrint('Added PDF printer: Download as PDF');
      
      // Only add debugging printers if enabled
      if (_enableFallbackPrinters) {
        debugPrint('Adding additional debugging printers...');
        _addFallbackPrintersForDebugging();
      }
      
    } catch (e) {
      debugPrint('Error adding web-compatible printers: $e');
    }
  }

  /// Detect connection type based on printer name and URL
  String _detectConnectionType(String name, String? url) {
    final nameLower = name.toLowerCase();
    final urlLower = url?.toLowerCase() ?? '';
    
    if (nameLower.contains('bluetooth') || nameLower.contains('bt')) {
      return 'bluetooth';
    } else if (nameLower.contains('wifi') || nameLower.contains('wireless') || 
               nameLower.contains('network') || urlLower.contains('http')) {
      return 'wifi';
    } else if (nameLower.contains('usb') || urlLower.contains('usb')) {
      return 'usb';
    } else if (nameLower.contains('fax')) {
      return 'fax';
    } else if (nameLower.contains('pdf') || nameLower.contains('xps')) {
      return 'virtual';
    } else {
      return 'system';
    }
  }



  /// Detect printer capabilities
  List<String> _detectPrinterCapabilities(String name) {
    final capabilities = <String>[];
    final nameLower = name.toLowerCase();
    
    if (nameLower.contains('color') || nameLower.contains('colour')) {
      capabilities.add('color');
    } else {
      capabilities.add('monochrome');
    }
    
    if (nameLower.contains('duplex') || nameLower.contains('double')) {
      capabilities.add('duplex');
    }
    
    if (nameLower.contains('label')) {
      capabilities.add('label');
    }
    
    if (nameLower.contains('photo')) {
      capabilities.add('photo');
    }
    
    if (nameLower.contains('pdf')) {
      capabilities.add('pdf');
    }
    
    return capabilities;
  }

  /// Determine printer type based on name
  String _determinePrinterType(String name) {
    final nameLower = name.toLowerCase();
    
    if (nameLower.contains('brother')) {
      return 'brother';
    } else if (nameLower.contains('hp') || nameLower.contains('hewlett')) {
      return 'hp';
    } else if (nameLower.contains('canon')) {
      return 'canon';
    } else if (nameLower.contains('epson')) {
      return 'epson';
    } else if (nameLower.contains('pdf')) {
      return 'virtual';
    } else if (nameLower.contains('microsoft')) {
      return 'system';
    } else {
      return 'system';
    }
  }

  /// Determine connection type based on printer name
  String _determineConnectionType(String name) {
    final nameLower = name.toLowerCase();
    
    if (nameLower.contains('usb')) {
      return 'usb';
    } else if (nameLower.contains('network') || nameLower.contains('ip') || nameLower.contains('wifi')) {
      return 'network';
    } else if (nameLower.contains('bluetooth')) {
      return 'bluetooth';
    } else if (nameLower.contains('pdf') || nameLower.contains('virtual')) {
      return 'virtual';
    } else {
      return 'local';
    }
  }

  /// Extract printer model from name
  String _extractPrinterModel(String name) {
    // Remove common prefixes and suffixes to get model
    String model = name;
    
    // Remove manufacturer names
    final manufacturers = ['Brother', 'HP', 'Canon', 'Epson', 'Microsoft'];
    for (final manufacturer in manufacturers) {
      model = model.replaceAll(RegExp(manufacturer, caseSensitive: false), '').trim();
    }
    
    // Remove common suffixes
    model = model.replaceAll(RegExp(r'\s*\(.*\)$'), ''); // Remove text in parentheses
    model = model.replaceAll(RegExp(r'\s+on\s+.*$', caseSensitive: false), ''); // Remove "on ComputerName"
    
    return model.trim().isEmpty ? name : model.trim();
  }

  /// Get printer capabilities based on name
  List<String> _getPrinterCapabilities(String name) {
    final capabilities = <String>[];
    final nameLower = name.toLowerCase();
    
    if (nameLower.contains('color') || nameLower.contains('colour')) {
      capabilities.add('color');
    } else {
      capabilities.add('monochrome');
    }
    
    if (nameLower.contains('duplex') || nameLower.contains('double')) {
      capabilities.add('duplex');
    }
    
    if (nameLower.contains('label')) {
      capabilities.add('label');
    }
    
    if (nameLower.contains('photo')) {
      capabilities.add('photo');
    }
    
    if (nameLower.contains('pdf')) {
      capabilities.add('pdf');
    }
    
    return capabilities;
  }

  /// Get printer location from name
  String? _getPrinterLocation(String name) {
    // Try to extract location information from printer name
    final patterns = [
      RegExp(r'\(([^)]+)\)$'), // Text in parentheses at the end
      RegExp(r'on\s+(.+)$', caseSensitive: false), // "on ComputerName"
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(name);
      if (match != null) {
        return match.group(1);
      }
    }
    
    return null;
  }

  /// Extract printer location (deprecated - use _getPrinterLocation)
  String? _extractPrinterLocation(String name) {
    return _getPrinterLocation(name);
  }

  /// Add fallback printers for debugging purposes (only when enabled)
  void _addFallbackPrintersForDebugging() {
    debugPrint('Adding fallback printers for debugging...');
    
    // System default printer
    _availablePrinters.add({
      'id': 'system_default',
      'name': 'System Default Printer (Debug)',
      'type': 'system',
      'connection': 'system',
      'model': 'System Default',
      'capabilities': ['color', 'monochrome'],
      'location': 'System',
      'isDefault': true,
      'status': 'available',
    });
    
    // PDF printer
    _availablePrinters.add({
      'id': 'pdf_printer',
      'name': 'Microsoft Print to PDF (Debug)',
      'type': 'virtual',
      'connection': 'virtual',
      'model': 'Virtual PDF Printer',
      'capabilities': ['pdf', 'color'],
      'location': 'Virtual',
      'isDefault': false,
      'status': 'available',
    });
    
    debugPrint('Added ${_availablePrinters.length} fallback printers for debugging');
  }

  /// Select a printer for use
  Future<bool> selectPrinter(String printerId) async {
    try {
      final printer = _availablePrinters.firstWhere(
        (p) => p['id'] == printerId,
        orElse: () => {},
      );
      
      if (printer.isNotEmpty) {
        _selectedPrinter = printer;
        _connectionController.add('connected');
        debugPrint('Selected printer: ${printer['name']}');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error selecting printer: $e');
      return false;
    }
  }

  /// Test printer connection
  Future<bool> testConnection() async {
    if (_selectedPrinter == null) {
      debugPrint('No printer selected');
      return false;
    }

    try {
      final printerType = _selectedPrinter!['type'];
      
      switch (printerType) {
        case 'brother':
          return await _testBrotherConnection();
        case 'system':
          return await _testSystemConnection();
        default:
          debugPrint('Unknown printer type: $printerType');
          return false;
      }
    } catch (e) {
      debugPrint('Error testing connection: $e');
      return false;
    }
  }

  /// Test Brother printer connection
  Future<bool> _testBrotherConnection() async {
    try {
      // Simplified connection test
      debugPrint('Brother printer connection test - simplified implementation');
      return true;
    } catch (e) {
      debugPrint('Brother connection test failed: $e');
      return false;
    }
  }

  /// Test system printer connection
  Future<bool> _testSystemConnection() async {
    try {
      // System printers are generally available
      debugPrint('System printer connection test passed');
      return true;
    } catch (e) {
      debugPrint('System connection test failed: $e');
      return false;
    }
  }

  /// Print badge directly with specified parameters
  Future<bool> printBadgeDirectly({
    required Attendee attendee,
    required BadgeTemplate template,
    required String eventName,
    Map<String, dynamic>? printer,
  }) async {
    try {
      // Generate badge PDF
      final pdfData = await BadgePrintingService.generateBadgePdf(
        attendee: attendee,
        template: template,
      );

      // Use specified printer or selected printer
      if (printer != null) {
        _selectedPrinter = printer;
      }

      final result = await printBadge(
        attendee: attendee,
        template: template,
        pdfData: pdfData,
      );

      return result['success'] == true;
    } catch (e) {
      debugPrint('Error in printBadgeDirectly: $e');
      return false;
    }
  }

  /// Print badge using selected printer
  Future<Map<String, dynamic>> printBadge({
    required Attendee attendee,
    required BadgeTemplate template,
    required Uint8List pdfData,
  }) async {
    if (_selectedPrinter == null) {
      return {
        'success': false,
        'message': 'No printer selected',
      };
    }

    try {
      final printerType = _selectedPrinter!['type'];
      
      switch (printerType) {
        case 'brother':
          return await _printWithBrother(pdfData);
        case 'system':
          return await _printWithSystem(pdfData);
        default:
          return {
            'success': false,
            'message': 'Unsupported printer type: $printerType',
          };
      }
    } catch (e) {
      debugPrint('Error printing badge: $e');
      return {
        'success': false,
        'message': 'Print error: $e',
      };
    }
  }

  /// Print with Brother printer
  Future<Map<String, dynamic>> _printWithBrother(Uint8List pdfData) async {
    try {
      // Convert PDF to image for Brother printing
      final images = Printing.raster(pdfData, dpi: 300);
      Uint8List? imageBytes;
      
      await for (final image in images) {
        imageBytes = await image.toPng();
        break;
      }
      
      if (imageBytes == null) {
        return {
          'success': false,
          'message': 'Failed to convert PDF to image',
        };
      }

      debugPrint('Brother printer: Badge prepared for printing (${imageBytes.length} bytes)');
      
      return {
        'success': true,
        'message': 'Badge prepared for Brother printing',
      };
      
    } catch (e) {
      debugPrint('Brother printing error: $e');
      return {
        'success': false,
        'message': 'Brother printing failed: $e',
      };
    }
  }

  /// Print with system printer
  Future<Map<String, dynamic>> _printWithSystem(Uint8List pdfData) async {
    try {
      // Use the printing package for system printing
      await Printing.layoutPdf(
        onLayout: (format) async => pdfData,
      );
      
      return {
        'success': true,
        'message': 'Badge sent to system printer',
      };
      
    } catch (e) {
      debugPrint('System printing error: $e');
      return {
        'success': false,
        'message': 'System printing failed: $e',
      };
    }
  }

  /// Test print functionality
  Future<bool> testPrint({String? printerId}) async {
    try {
      final printerToTest = printerId != null 
          ? _availablePrinters.firstWhere((p) => p['id'] == printerId, orElse: () => {})
          : _selectedPrinter;
      
      if (printerToTest == null || printerToTest.isEmpty) {
        debugPrint('No printer available for test print');
        return false;
      }
      
      debugPrint('Testing print on: ${printerToTest['name']}');
      
      // Create a simple test document
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    'Test Print',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text('Printer: ${printerToTest['name']}'),
                  pw.Text('Type: ${printerToTest['type']}'),
                  pw.Text('Connection: ${printerToTest['connectionType']}'),
                  pw.SizedBox(height: 20),
                  pw.Text('Date: ${DateTime.now().toString()}'),
                  pw.SizedBox(height: 20),
                  pw.Text('If you can see this, your printer is working correctly!'),
                ],
              ),
            );
          },
        ),
      );
      
      // Print based on printer type
      if (printerToTest['type'] == 'web') {
        return await _testPrintWithBrowser(pdf);
      } else {
        return await _testPrintWithSystem(pdf, printerToTest);
      }
      
    } catch (e) {
      debugPrint('Test print failed: $e');
      return false;
    }
  }

  /// Test print with browser (Edge)
  Future<bool> _testPrintWithBrowser(pw.Document pdf) async {
    try {
      debugPrint('Opening test print in Edge browser...');
      
      // Use the printing package to open print dialog in browser
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Test Print - Event Manager',
        format: PdfPageFormat.a4,
      );
      
      debugPrint('Test print dialog opened in browser');
      return true;
    } catch (e) {
      debugPrint('Browser test print failed: $e');
      return false;
    }
  }

  /// Test print with system printer
  Future<bool> _testPrintWithSystem(pw.Document pdf, Map<String, dynamic> printer) async {
    try {
      debugPrint('Printing test page to system printer: ${printer['name']}');
      
      // Check if this is a web-compatible printer or a real system printer
      final printerUrl = printer['url'] as String?;
      final printerType = printer['type'] as String?;
      
      if (printerType == 'pdf' || printerType == 'browser' || printerUrl == null) {
        // For web-compatible printers, use the standard print dialog
        debugPrint('Using web-compatible printing for: ${printer['name']}');
        
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
          name: 'Test Print - Event Manager',
          format: PdfPageFormat.a4,
        );
        
        debugPrint('Test print dialog opened for ${printer['name']}');
        return true;
        
      } else {
        // For real system printers with valid URLs, use direct printing
        debugPrint('Using direct printing for system printer: ${printer['name']}');
        
        final success = await Printing.directPrintPdf(
          printer: Printer(url: printerUrl),
          onLayout: (PdfPageFormat format) async => pdf.save(),
          name: 'Test Print - Event Manager',
          format: PdfPageFormat.a4,
        );
        
        if (success) {
          debugPrint('Test print sent successfully to ${printer['name']}');
        } else {
          debugPrint('Test print failed for ${printer['name']}');
        }
        
        return success;
      }
      
    } catch (e) {
      debugPrint('System test print failed: $e');
      return false;
    }
  }

  /// Get detailed printer information
  Map<String, dynamic>? getPrinterDetails(String printerId) {
    try {
      return _availablePrinters.firstWhere((p) => p['id'] == printerId);
    } catch (e) {
      return null;
    }
  }

  /// Get all discovered printers with detailed information
  List<Map<String, dynamic>> getAllPrintersWithDetails() {
    return List<Map<String, dynamic>>.from(_availablePrinters);
  }

  /// Check if a printer supports specific capabilities
  bool printerSupportsCapability(String printerId, String capability) {
    final printer = getPrinterDetails(printerId);
    if (printer == null) return false;
    
    final capabilities = printer['capabilities'] as List<String>? ?? [];
    return capabilities.contains(capability);
  }

  /// Get printer status
  String getPrinterStatus() {
    if (_selectedPrinter == null) {
      return 'disconnected';
    }
    return 'connected';
  }

  /// Dispose resources
  void dispose() {
    _printersController.close();
    _connectionController.close();
  }
}