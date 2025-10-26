import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import '../models/attendee.dart';
import '../models/badge_template.dart';
import '../models/event.dart';
import '../models/brother_printer.dart';
import '../services/api_service.dart';
import '../services/badge_printing_service.dart';
import '../services/file_service.dart';
import '../services/native_printer_service.dart';
import '../services/brother_printer_service.dart';
import '../services/connection_manager.dart';
import '../services/connection_health_monitor.dart';
import '../services/print_job_processor.dart';
import '../services/print_queue_manager.dart';
import '../services/mfi_authentication_service.dart';
import '../services/brother_error_handler.dart';
import '../main.dart';

class BadgeProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<BadgeTemplate> _templates = [];
  BadgeTemplate? _selectedTemplate;
  bool _isLoading = false;
  String? _errorMessage;
  List<Printer> _availablePrinters = [];
  Printer? _selectedPrinter;
  
  // Cache for event data to avoid repeated API calls
  Map<String, Event> _eventCache = {};

  // Native printer service
  final NativePrinterService _nativePrinterService = NativePrinterService();
  List<Map<String, dynamic>> _discoveredPrinters = [];
  Map<String, dynamic>? _selectedNativePrinter;
  bool _isDiscoveringPrinters = false;
  bool _useNativePrinting = false;

  // Brother printer services
  final BrotherPrinterServiceImpl _brotherPrinterService = BrotherPrinterServiceImpl();
  final ConnectionManagerImpl _connectionManager = ConnectionManagerImpl();
  final ConnectionHealthMonitor _healthMonitor = ConnectionHealthMonitor();
  final PrintJobProcessor _jobProcessor = PrintJobProcessor();
  final PrintQueueManager _queueManager = PrintQueueManager();
  final MFiAuthenticationService _mfiService = MFiAuthenticationService();
  final BrotherErrorHandler _errorHandler = BrotherErrorHandler();

  // Brother printer state
  List<BrotherPrinter> _brotherPrinters = [];
  BrotherPrinter? _selectedBrotherPrinter;
  bool _isBrotherPrintingEnabled = false;
  bool _isDiscoveringBrotherPrinters = false;
  PrinterConnection? _activeBrotherConnection;
  BrotherError? _lastBrotherError;

  // Getters
  List<BadgeTemplate> get templates => _templates;
  BadgeTemplate? get selectedTemplate => _selectedTemplate;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Printer> get availablePrinters => _availablePrinters;
  Printer? get selectedPrinter => _selectedPrinter;

  // Native printer getters
  List<Map<String, dynamic>> get discoveredPrinters => _discoveredPrinters;
  Map<String, dynamic>? get selectedNativePrinter => _selectedNativePrinter;
  bool get isDiscoveringPrinters => _isDiscoveringPrinters;
  bool get useNativePrinting => _useNativePrinting;
  Stream<List<Map<String, dynamic>>> get printersStream => _nativePrinterService.printersStream;

  // Brother printer getters
  List<BrotherPrinter> get brotherPrinters => _brotherPrinters;
  BrotherPrinter? get selectedBrotherPrinter => _selectedBrotherPrinter;
  bool get isBrotherPrintingEnabled => _isBrotherPrintingEnabled;
  bool get isDiscoveringBrotherPrinters => _isDiscoveringBrotherPrinters;
  PrinterConnection? get activeBrotherConnection => _activeBrotherConnection;
  bool get hasBrotherConnection => _activeBrotherConnection?.isConnected == true;
  BrotherError? get lastBrotherError => _lastBrotherError;

  /// Cache event data for template selection
  void cacheEvent(Event event) {
    _eventCache[event.id] = event;
    print('📦 BADGE PROVIDER: Cached event data for: ${event.name} (${event.id})');
    print('📦 BADGE PROVIDER: Regular template ID: "${event.regularBadgeTemplateId}"');
    print('📦 BADGE PROVIDER: VIP template ID: "${event.vipBadgeTemplateId}"');
    print('📦 BADGE PROVIDER: Available templates when caching: ${_templates.map((t) => '${t.name}(${t.id})').join(", ")}');
    
    // Verify template IDs exist in loaded templates
    if (event.regularBadgeTemplateId != null) {
      final regularExists = _templates.any((t) => t.id == event.regularBadgeTemplateId);
      print('📦 BADGE PROVIDER: Regular template "${event.regularBadgeTemplateId}" exists: $regularExists');
    }
    if (event.vipBadgeTemplateId != null) {
      final vipExists = _templates.any((t) => t.id == event.vipBadgeTemplateId);
      print('📦 BADGE PROVIDER: VIP template "${event.vipBadgeTemplateId}" exists: $vipExists');
    }
  }

  /// Fetch badge templates globally (like web app)
  Future<void> fetchTemplates([String? eventId]) async {
    _setLoading(true);
    _clearError();

    try {
      // CRITICAL FIX: Load ALL templates by default (like web app)
      // Only filter by eventId if explicitly provided
      if (eventId != null) {
        print('🔍 BADGE PROVIDER: Fetching templates for event: $eventId');
      } else {
        print('🔍 BADGE PROVIDER: Fetching ALL templates globally (like web app)');
      }
      final response = await _apiService.getBadgeTemplates(eventId: eventId);
      _templates = response
          .map((json) => BadgeTemplate.fromJson(json))
          .toList();
      
      print('🔍 BADGE PROVIDER: Loaded ${_templates.length} templates');
      
      // Validate and fix template dimensions and fields
      for (int i = 0; i < _templates.length; i++) {
        final template = _templates[i];
        final dimensions = template.dimensions;
        final width = (dimensions['width'] ?? 400).toDouble();
        final height = (dimensions['height'] ?? 300).toDouble();
        
        print('🔍 BADGE PROVIDER: Template "${template.name}" has ${template.fields.length} fields');
        
        // Check if template has no fields and create fallback
        if (template.fields.isEmpty) {
          print('⚠️ BADGE PROVIDER: Template "${template.name}" has no fields, creating fallback');
          _templates[i] = _createFallbackTemplate(template);
        }
        
        if (width <= 0 || height <= 0) {
          print('Warning: Template "${template.name}" has invalid dimensions (${width}x${height}). Using defaults.');
          // Create a corrected template with default dimensions
          _templates[i] = template.copyWith(
            dimensions: {
              'width': width > 0 ? width : 85.6,
              'height': height > 0 ? height : 53.98,
              'units': dimensions['units'] ?? 'mm',
            },
          );
        }
      }
      
      // Don't auto-select a template here - let _selectTemplateForAttendee handle it
      // This ensures we use the correct template based on VIP status and event assignment
      print('✅ BADGE PROVIDER: Loaded ${_templates.length} templates, will select based on attendee VIP status');
    } catch (e) {
      print('❌ BADGE PROVIDER: Error fetching badge templates: $e');
      _setError('Error fetching badge templates: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Select a badge template
  void selectTemplate(BadgeTemplate template) {
    _selectedTemplate = template;
    notifyListeners();
  }

  /// Fetch available printers
  Future<void> fetchAvailablePrinters() async {
    try {
      _availablePrinters = await BadgePrintingService.getAvailablePrinters();
      
      // Also discover native printers for mobile
      await discoverNativePrinters();
      
      // Auto-select browser printer if none selected and direct printing is enabled
      if (_selectedNativePrinter == null && _discoveredPrinters.isNotEmpty) {
        final browserPrinter = _discoveredPrinters.firstWhere(
          (printer) => printer['id'] == 'browser_print',
          orElse: () => _discoveredPrinters.first,
        );
        selectNativePrinter(browserPrinter);
        print('🔧 BADGE PROVIDER: Auto-selected printer: ${browserPrinter['name']}');
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Error fetching printers: ${e.toString()}');
    }
  }

  /// Select a printer
  void selectPrinter(Printer printer) {
    _selectedPrinter = printer;
    notifyListeners();
  }

  /// Print a single badge
  Future<bool> printBadge({
    required Attendee attendee,
    String? eventName,
    bool useDirectPrinting = false,
    bool useBrotherPrinter = false,
    JobPriority priority = JobPriority.normal,
  }) async {
    print('🔍 BADGE PROVIDER: printBadge called for ${attendee.fullName}');
    print('🔍 BADGE PROVIDER: Event name: $eventName');
    print('🔍 BADGE PROVIDER: Use direct printing: $useDirectPrinting');
    print('🔍 BADGE PROVIDER: Use Brother printer: $useBrotherPrinter');
    print('🔍 BADGE PROVIDER: Selected native printer: $_selectedNativePrinter');
    print('🔍 BADGE PROVIDER: Selected web printer: $_selectedPrinter');
    print('🔍 BADGE PROVIDER: Selected Brother printer: ${_selectedBrotherPrinter?.displayName}');
    
    // Select the correct template based on VIP status
    await _selectTemplateForAttendee(attendee);
    if (_selectedTemplate == null) {
      print('❌ BADGE PROVIDER: No template selected after _selectTemplateForAttendee');
      _setError('No badge design found');
      return false;
    }

    print('✅ BADGE PROVIDER: Template selected: ${_selectedTemplate!.name}');
    _clearError();

    try {
      // Use Brother printer if requested and available
      if (useBrotherPrinter && _isBrotherPrintingEnabled) {
        return await printBadgeWithBrother(
          attendee: attendee,
          eventName: eventName,
          priority: priority,
        );
      }

      // Check if "Download as PDF" printer is selected with direct printing
      if (useDirectPrinting && _selectedNativePrinter != null &&
          _selectedNativePrinter!['id'] == 'pdf_download') {
        print('📥 Auto-downloading PDF (direct printing with PDF printer selected)');
        final filePath = await saveBadgeToDownloads(
          attendee: attendee,
          eventName: eventName,
        );
        
        if (filePath != null) {
          // Show success message
          _showSuccessMessage('PDF saved successfully!\nLocation: $filePath');
          return true;
        } else {
          _showErrorMessage('Failed to save PDF to Downloads folder');
          return false;
        }
      }
        
      if (useDirectPrinting && _selectedNativePrinter != null) {
        // Handle different printer types for direct printing
        if (_selectedNativePrinter!['id'] == 'browser_print') {
          // Browser printer - use layoutPdf for direct printing
          print('🖨️ Direct printing with browser printer');
          final success = await BadgePrintingService.printBadge(
            attendee: attendee,
            template: _selectedTemplate!,
            eventName: eventName ?? 'Event',
            printerName: null, // Use default browser printing
          );
          
          if (success) {
            await _markBadgeGenerated(attendee.id);
            // Silent printing - no success message
          }
          return success;
        } else {
          // Other native printers
          print('🖨️ Direct printing with native printer: ${_selectedNativePrinter!['name']}');
          final success = await BadgePrintingService.printBadge(
            attendee: attendee,
            template: _selectedTemplate!,
            eventName: eventName ?? 'Event',
            printerName: _selectedNativePrinter!['url'],
          );

          if (success) {
            await _markBadgeGenerated(attendee.id);
            // Silent printing - no success message
          }
          return success;
        }
      } else if (useDirectPrinting && _selectedPrinter != null) {
        // Fallback for web printers
        print('🖨️ Direct printing with web printer: ${_selectedPrinter!.name}');
        final success = await BadgePrintingService.printBadge(
          attendee: attendee,
          template: _selectedTemplate!,
          eventName: eventName ?? 'Event',
          printerName: _selectedPrinter!.url,
        );

        if (success) {
          await _markBadgeGenerated(attendee.id);
          // Silent printing - no success message
        }
        return success;
      } else {
        // Show print preview
        return false; // Will be handled by the UI
      }
    } catch (e) {
      _setError('Error printing badge: ${e.toString()}');
      return false;
    }
  }

  /// Print multiple badges
  Future<bool> printMultipleBadges({
    required List<Attendee> attendees,
    String? eventName,
    bool useDirectPrinting = false,
    bool useBrotherPrinter = false,
    JobPriority priority = JobPriority.normal,
  }) async {
    if (_selectedTemplate == null) {
      _setError('No badge template selected');
      return false;
    }

    if (attendees.isEmpty) {
      _setError('No attendees selected for printing');
      return false;
    }

    _clearError();

    try {
      // Use Brother printer if requested and available
      if (useBrotherPrinter && _isBrotherPrintingEnabled) {
        return await printMultipleBadgesWithBrother(
          attendees: attendees,
          eventName: eventName,
          priority: priority,
        );
      }

      // Check if "Download as PDF" printer is selected with direct printing
      if (useDirectPrinting && _selectedNativePrinter != null && 
          _selectedNativePrinter!['id'] == 'pdf_download') {
        print('📥 Auto-downloading multiple badges PDF (direct printing with PDF printer selected)');
        final filePath = await saveMultipleBadgesToDownloads(
          attendees: attendees,
          eventName: eventName,
        );
        
        if (filePath != null) {
          // Show success message
          _showSuccessMessage('${attendees.length} PDFs saved successfully!\nLocation: $filePath');
          return true;
        } else {
          _showErrorMessage('Failed to save PDFs to Downloads folder');
          return false;
        }
      }
      
      final pdfData = await BadgePrintingService.generateMultipleBadgesPdf(
        attendees: attendees,
        template: _selectedTemplate!,
        eventName: eventName,
      );

      if (useDirectPrinting && _selectedNativePrinter != null) {
        // Handle different printer types for direct printing
        if (_selectedNativePrinter!['id'] == 'browser_print') {
          // Browser printer - use layoutPdf for direct printing
          print('🖨️ Direct printing multiple badges with browser printer');
          await Printing.layoutPdf(
            onLayout: (format) async => pdfData,
            name: 'Badges_${attendees.length}_attendees',
          );
          
          // Mark badges as generated
          for (final attendee in attendees) {
            await _markBadgeGenerated(attendee.id);
          }
          
          // Silent printing - no success message
          return true;
        } else {
          // Other native printers
          print('🖨️ Direct printing multiple badges with native printer: ${_selectedNativePrinter!['name']}');
          await Printing.directPrintPdf(
            printer: Printer(url: _selectedNativePrinter!['url']),
            onLayout: (format) async => pdfData,
          );

          // Mark badges as generated
          for (final attendee in attendees) {
            await _markBadgeGenerated(attendee.id);
          }
          
          // Silent printing - no success message
          return true;
        }
      } else if (useDirectPrinting && _selectedPrinter != null) {
        // Fallback for web printers
        print('🖨️ Direct printing multiple badges with web printer: ${_selectedPrinter!.name}');
        await Printing.directPrintPdf(
          printer: _selectedPrinter!,
          onLayout: (format) async => pdfData,
        );

        // Mark badges as generated
        for (final attendee in attendees) {
          await _markBadgeGenerated(attendee.id);
        }
        
        // Silent printing - no success message
        return true;
      } else {
        // Show print preview
        await Printing.layoutPdf(
          onLayout: (format) async => pdfData,
          name: 'Badges_${attendees.length}_attendees',
        );

        // Mark badges as generated
        for (final attendee in attendees) {
          await _markBadgeGenerated(attendee.id);
        }

        return true;
      }
    } catch (e) {
      _setError('Error printing badges: ${e.toString()}');
      return false;
    }
  }

  /// Save badge PDF to Downloads folder
  Future<String?> saveBadgeToDownloads({
    required Attendee attendee,
    String? eventName,
  }) async {
    if (_selectedTemplate == null) {
      _setError('No badge template selected');
      return null;
    }

    _clearError();

    try {
      final pdfData = await BadgePrintingService.generateBadgePdf(
        attendee: attendee,
        template: _selectedTemplate!,
        eventName: eventName,
      );

      final fileName = 'Badge_${attendee.fullName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      // For web platforms, use browser download
      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (format) async => pdfData,
          name: fileName,
        );
        
        // Mark badge as generated
        await _markBadgeGenerated(attendee.id);
        return 'web_download_$fileName';
      }
      
      // For mobile platforms, save to Downloads folder
      final filePath = await FileService.savePdfToDownloads(
        pdfData: pdfData,
        fileName: fileName,
      );

      if (filePath != null) {
        // Mark badge as generated
        await _markBadgeGenerated(attendee.id);
        return filePath;
      } else {
        _setError('Failed to save badge to Downloads folder');
        return null;
      }
    } catch (e) {
      _setError('Error saving badge: ${e.toString()}');
      return null;
    }
  }

  /// Save multiple badges PDF to Downloads folder
  Future<String?> saveMultipleBadgesToDownloads({
    required List<Attendee> attendees,
    String? eventName,
  }) async {
    if (_selectedTemplate == null) {
      _setError('No badge template selected');
      return null;
    }

    if (attendees.isEmpty) {
      _setError('No attendees selected for saving');
      return null;
    }

    _clearError();

    try {
      final pdfData = await BadgePrintingService.generateMultipleBadgesPdf(
        attendees: attendees,
        template: _selectedTemplate!,
        eventName: eventName,
      );

      final fileName = 'Badges_${attendees.length}_attendees_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      // For web platforms, use browser download
      if (kIsWeb) {
        await Printing.layoutPdf(
          onLayout: (format) async => pdfData,
          name: fileName,
        );
        
        // Mark badges as generated
        for (final attendee in attendees) {
          await _markBadgeGenerated(attendee.id);
        }
        return 'web_download_$fileName';
      }
      
      // For mobile platforms, save to Downloads folder
      final filePath = await FileService.savePdfToDownloads(
        pdfData: pdfData,
        fileName: fileName,
      );

      if (filePath != null) {
        // Mark badges as generated
        for (final attendee in attendees) {
          await _markBadgeGenerated(attendee.id);
        }
        return filePath;
      } else {
        _setError('Failed to save badges to Downloads folder');
        return null;
      }
    } catch (e) {
      _setError('Error saving badges: ${e.toString()}');
      return null;
    }
  }

  /// Show print preview for a single badge
  Future<void> showPrintPreview({
    required Attendee attendee,
    String? eventName,
  }) async {
    // Select the correct template based on VIP status
    await _selectTemplateForAttendee(attendee);
    if (_selectedTemplate == null) {
      _setError('No badge template selected');
      return;
    }

    try {
      final pdfData = await BadgePrintingService.generateBadgePdf(
        attendee: attendee,
        template: _selectedTemplate!,
        eventName: eventName,
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfData,
        name: 'Badge_${attendee.fullName.replaceAll(' ', '_')}',
      );

      // Mark badge as generated
      await _markBadgeGenerated(attendee.id);
    } catch (e) {
      _setError('Error showing print preview: ${e.toString()}');
    }
  }

  /// Generate badge PDF data
  Future<Uint8List?> generateBadgePdf({
    required Attendee attendee,
    String? eventName,
  }) async {
    // Select the correct template based on VIP status
    await _selectTemplateForAttendee(attendee);
    if (_selectedTemplate == null) {
      _setError('No badge template selected');
      return null;
    }

    try {
      return await BadgePrintingService.generateBadgePdf(
        attendee: attendee,
        template: _selectedTemplate!,
        eventName: eventName,
      );
    } catch (e) {
      _setError('Error generating badge PDF: ${e.toString()}');
      return null;
    }
  }

  /// Check if printing is available
  Future<bool> isPrintingAvailable() async {
    return await BadgePrintingService.isPrintingAvailable();
  }

  /// Get default template for an event
  BadgeTemplate? getDefaultTemplate(String eventId) {
    // Since templates have eventId: null, we look for any template marked as default
    // or return the first available template as fallback
    return _templates
        .where((template) => template.isDefault)
        .firstOrNull ?? 
        _templates.firstOrNull;
  }

  /// Get templates for a specific event
  List<BadgeTemplate> getTemplatesForEvent(String eventId) {
    // Since templates have eventId: null, we return all templates
    // The event-specific selection is handled by regularBadgeTemplateId and vipBadgeTemplateId
    return _templates;
  }

  /// Select the appropriate template for an attendee based on VIP status
  Future<void> _selectTemplateForAttendee(Attendee attendee) async {
    try {
      print('🔍 BADGE PROVIDER: Starting template selection for attendee: ${attendee.fullName}');
      print('🔍 BADGE PROVIDER: Attendee event ID: ${attendee.eventId}');
      print('🔍 BADGE PROVIDER: Attendee VIP status: ${attendee.isVip}');
      print('🔍 BADGE PROVIDER: Available templates count: ${_templates.length}');
      
      // Get the event to find template IDs
      print('🔍 BADGE PROVIDER: Fetching event details for: ${attendee.eventId}');
      
      // First try to get event from cache
      Event? event = _eventCache[attendee.eventId];
      if (event == null) {
        print('🔍 BADGE PROVIDER: Event not in cache, fetching from API...');
        event = await _apiService.getEvent(attendee.eventId);
        if (event != null) {
          _eventCache[attendee.eventId] = event;
        }
      } else {
        print('✅ BADGE PROVIDER: Using cached event data');
      }
      
      if (event == null) {
        print('❌ BADGE PROVIDER: Event not found for attendee: ${attendee.eventId}');
        print('🔍 BADGE PROVIDER: Available cached events: ${_eventCache.keys.join(", ")}');
        _setError('Event not found for attendee');
        return;
      }
      
      print('✅ BADGE PROVIDER: Event found: ${event.name}');
      print('🔍 BADGE PROVIDER: Event regular template ID: "${event.regularBadgeTemplateId}"');
      print('🔍 BADGE PROVIDER: Event VIP template ID: "${event.vipBadgeTemplateId}"');
      print('🔍 BADGE PROVIDER: Event regular template ID is null: ${event.regularBadgeTemplateId == null}');
      print('🔍 BADGE PROVIDER: Event VIP template ID is null: ${event.vipBadgeTemplateId == null}');

      print('🔍 BADGE PROVIDER: Selecting template for ${attendee.isVip ? "VIP" : "regular"} attendee: ${attendee.fullName}');

      // Determine which template ID to use
      final templateId = attendee.isVip 
          ? event.vipBadgeTemplateId 
          : event.regularBadgeTemplateId;

      print('🔍 BADGE PROVIDER: Looking for template ID: $templateId');

      if (templateId == null) {
        print('❌ BADGE PROVIDER: No ${attendee.isVip ? "VIP" : "regular"} template assigned to event');
        print('❌ BADGE PROVIDER: Event "${event.name}" (${event.id}) has no ${attendee.isVip ? "VIP" : "regular"} template ID');
        print('❌ BADGE PROVIDER: Available template IDs in database:');
        for (final template in _templates) {
          print('  - "${template.id}" (${template.name}) - VIP: ${template.isVipTemplate}');
        }
        _selectedTemplate = null; // Ensure selectedTemplate is null
        _setError('No badge template available for this event - no ${attendee.isVip ? "VIP" : "regular"} template assigned');
        return;
      }

      // Find the template in our loaded templates by ID (not by eventId)
      // Templates have eventId: null but are identified by their unique ID
      print('🔍 BADGE PROVIDER: Searching for template ID: "$templateId"');
      print('🔍 BADGE PROVIDER: Available template IDs: ${_templates.map((t) => '"${t.id}"').join(", ")}');
      
      // ENHANCED DEBUG: Log detailed template information
      print('🔍 BADGE PROVIDER: Template search details:');
      for (int i = 0; i < _templates.length; i++) {
        final t = _templates[i];
        print('  Template $i: "${t.name}" (ID: "${t.id}", VIP: ${t.isVipTemplate})');
        print('    - ID length: ${t.id.length}, Target length: ${templateId.length}');
        print('    - ID bytes: ${t.id.codeUnits}, Target bytes: ${templateId.codeUnits}');
        print('    - Exact match: ${t.id == templateId}');
      }
      
      // Try exact match first
      var template = _templates.where((t) => t.id == templateId).firstOrNull;
      
      // If not found, try case-insensitive match
      if (template == null) {
        print('🔍 BADGE PROVIDER: Exact match failed, trying case-insensitive match...');
        template = _templates.where((t) => t.id.toLowerCase() == templateId.toLowerCase()).firstOrNull;
      }
      
      // If still not found, try trimming whitespace
      if (template == null) {
        print('🔍 BADGE PROVIDER: Case-insensitive match failed, trying trimmed match...');
        template = _templates.where((t) => t.id.trim() == templateId.trim()).firstOrNull;
      }
      
      if (template == null) {
        print('❌ BADGE PROVIDER: Template not found: "$templateId"');
        print('🔍 BADGE PROVIDER: Available template names: ${_templates.map((t) => '"${t.name}"').join(", ")}');
        print('🔍 BADGE PROVIDER: Template ID comparison failed - checking for exact match...');
        
        // Debug: Check if there are any similar IDs
        for (final t in _templates) {
          print('🔍 BADGE PROVIDER: Template "${t.name}" has ID "${t.id}" (length: ${t.id.length})');
          if (t.id.contains(templateId) || templateId.contains(t.id)) {
            print('⚠️ BADGE PROVIDER: Potential partial match found!');
          }
        }
        
        _selectedTemplate = null; // Ensure selectedTemplate is null
        _setError('No badge design found - template "$templateId" not found in loaded templates');
        return;
      }

      _selectedTemplate = template;
      print('✅ BADGE PROVIDER: Selected ${attendee.isVip ? "VIP" : "regular"} template: ${template.name}');
      print('✅ BADGE PROVIDER: Template has ${template.fields.length} fields');
      print('✅ BADGE PROVIDER: Template dimensions: ${template.dimensions}');
      print('✅ BADGE PROVIDER: Template background: ${template.logoUrl ?? "none"}');
      notifyListeners();
    } catch (e) {
      print('❌ BADGE PROVIDER: Error selecting template for attendee: $e');
      _setError('Error selecting badge template: ${e.toString()}');
    }
  }

  /// Mark badge as generated in the backend
  Future<void> _markBadgeGenerated(String attendeeId) async {
    try {
      // TODO: Implement markBadgeGenerated in API service if needed
      // await _apiService.markBadgeGenerated(attendeeId);
      print('Badge generated for attendee: $attendeeId');
    } catch (e) {
      // Log error but don't fail the printing process
      print('Error marking badge as generated: $e');
    }
  }

  /// Create a fallback template with default fields for templates that have no fields
  BadgeTemplate _createFallbackTemplate(BadgeTemplate originalTemplate) {
    return originalTemplate.copyWith(
      fields: [
        // Name field
        BadgeField(
          id: 'name_field',
          type: 'text',
          content: '{{firstName}} {{lastName}}',
          position: {'x': 5.0, 'y': 10.0},
          size: {'width': 75.0, 'height': 15.0},
          style: {
            'fontSize': 16,
            'fontWeight': 'bold',
            'color': '#000000',
            'textAlign': 'center',
          },
        ),
        // Email field
        BadgeField(
          id: 'email_field',
          type: 'text',
          content: '{{email}}',
          position: {'x': 5.0, 'y': 25.0},
          size: {'width': 75.0, 'height': 10.0},
          style: {
            'fontSize': 10,
            'fontWeight': 'normal',
            'color': '#666666',
            'textAlign': 'center',
          },
        ),
        // QR Code field
        BadgeField(
          id: 'qr_field',
          type: 'qr',
          content: null,
          position: {'x': 60.0, 'y': 35.0},
          size: {'width': 15.0, 'height': 15.0},
          style: {},
        ),
        // Ticket type field
        BadgeField(
          id: 'ticket_type_field',
          type: 'text',
          content: '{{ticketType}}',
          position: {'x': 5.0, 'y': 35.0},
          size: {'width': 50.0, 'height': 8.0},
          style: {
            'fontSize': 8,
            'fontWeight': 'normal',
            'color': '#333333',
            'textAlign': 'left',
          },
        ),
      ],
    );
  }

  /// Create a default badge template
  BadgeTemplate createDefaultTemplate(String eventId) {
    return BadgeTemplate(
      id: 'default_$eventId',
      name: 'Default Template',
      eventId: eventId,
      labelSizeId: 'default',
      isVipTemplate: false,
      backgroundColor: '#FFFFFF',
      backgroundImage: null,
      backgroundSettings: null,
      textColor: '#000000',
      logoUrl: null,
      dimensions: {
        'width': 85.6,
        'height': 53.98,
        'units': 'mm',
      },
      isDefault: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isActive: true,
      fields: [
        // Name field
        BadgeField(
          id: 'name_field',
          type: 'text',
          content: '{{firstName}} {{lastName}}',
          position: {'x': 5.0, 'y': 10.0},
          size: {'width': 75.0, 'height': 15.0},
          style: {
            'fontSize': 16,
            'fontWeight': 'bold',
            'color': '#000000',
            'textAlign': 'center',
          },
        ),
        // Email field
        BadgeField(
          id: 'email_field',
          type: 'text',
          content: '{{email}}',
          position: {'x': 5.0, 'y': 25.0},
          size: {'width': 75.0, 'height': 10.0},
          style: {
            'fontSize': 10,
            'fontWeight': 'normal',
            'color': '#666666',
            'textAlign': 'center',
          },
        ),
        // QR Code field
        BadgeField(
          id: 'qr_field',
          type: 'qr',
          content: null,
          position: {'x': 60.0, 'y': 35.0},
          size: {'width': 15.0, 'height': 15.0},
          style: {},
        ),
        // Ticket type field
        BadgeField(
          id: 'ticket_type_field',
          type: 'text',
          content: '{{ticketType}}',
          position: {'x': 5.0, 'y': 35.0},
          size: {'width': 50.0, 'height': 8.0},
          style: {
            'fontSize': 8,
            'fontWeight': 'normal',
            'color': '#333333',
            'textAlign': 'left',
          },
        ),
      ],
    );
  }

  /// Initialize native printer service
  Future<void> initializeNativePrinting() async {
    try {
      await _nativePrinterService.initialize();
      
      // Listen to printer discovery updates
      _nativePrinterService.printersStream.listen((printers) {
        _discoveredPrinters = printers;
        notifyListeners();
      });
      
    } catch (e) {
      _setError('Error initializing native printing: ${e.toString()}');
    }
  }

  /// Show success message to user
  void _showSuccessMessage(String message) {
    // Implementation depends on your UI framework
    // For now, just clear any existing error
    _clearError();
    debugPrint('✅ Success: $message');
  }

  /// Show error message to user
  void _showErrorMessage(String message) {
    _setError(message);
    debugPrint('❌ Error: $message');
  }

  /// Handle Brother printer errors with enhanced error processing
  void _handleBrotherError(
    String errorMessage, {
    String? errorCode,
    Map<String, dynamic> context = const {},
  }) {
    // Parse and categorize the error
    final brotherError = _errorHandler.parseError(
      errorMessage,
      errorCode: errorCode,
      context: context,
    );

    _lastBrotherError = brotherError;
    
    // Set user-friendly error message
    final userMessage = _errorHandler.getUserFriendlyMessage(brotherError);
    _setError(userMessage);
    
    debugPrint('🔍 Brother Error: ${brotherError.type} - ${brotherError.code}');
    debugPrint('🔍 User Message: $userMessage');
    debugPrint('🔍 Recoverable: ${brotherError.isRecoverable}');
    
    notifyListeners();
  }

  /// Get Brother error statistics
  Map<String, dynamic> getBrotherErrorStatistics() {
    return _errorHandler.getErrorStatistics();
  }

  /// Clear Brother error history
  void clearBrotherErrorHistory() {
    _errorHandler.clearErrorHistory();
    _lastBrotherError = null;
    notifyListeners();
  }

  /// Get troubleshooting steps for the last error
  List<String> getLastErrorTroubleshootingSteps() {
    if (_lastBrotherError == null) return [];
    return _errorHandler.getTroubleshootingSteps(_lastBrotherError!);
  }

  /// Check if last error is recoverable
  bool isLastErrorRecoverable() {
    if (_lastBrotherError == null) return false;
    return _errorHandler.isRecoverable(_lastBrotherError!);
  }

  /// Initialize Brother printer services
  Future<void> initializeBrotherPrinting() async {
    try {
      debugPrint('🔧 Initializing Brother printer services...');
      
      // Initialize all Brother services
      await _brotherPrinterService.initialize();
      await _connectionManager.initializeConnections();
      await _healthMonitor.startMonitoring();
      await _jobProcessor.initialize();
      await _queueManager.initialize();
      await _mfiService.initialize();

      // Listen to connection events
      _connectionManager.connectionEvents.listen(_handleConnectionEvent);
      
      // Listen to printer status updates
      _brotherPrinterService.statusStream.listen(_handlePrinterStatusUpdate);

      // Listen to health monitoring
      _healthMonitor.healthStream.listen(_handleHealthUpdate);

      // Listen to queue statistics
      _queueManager.statisticsStream.listen(_handleQueueUpdate);

      _isBrotherPrintingEnabled = true;
      debugPrint('✅ Brother printer services initialized');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Brother printer initialization failed: $e');
      _handleBrotherError('Brother printer initialization failed: $e');
    }
  }

  /// Discover Brother printers
  Future<void> discoverBrotherPrinters() async {
    if (_isDiscoveringBrotherPrinters) return;

    try {
      debugPrint('🔍 Starting Brother printer discovery...');
      _isDiscoveringBrotherPrinters = true;
      notifyListeners();

      // Discover printers using connection manager
      final connections = await _connectionManager.scanForPrinters();
      
      // Get printer details
      _brotherPrinters.clear();
      for (final connection in connections) {
        final printer = _connectionManager.discoveredPrinters[connection.printerId];
        if (printer != null) {
          _brotherPrinters.add(printer);
        }
      }

      debugPrint('✅ Brother printer discovery completed: ${_brotherPrinters.length} printers found');
      
      // Auto-select first available printer if none selected
      if (_selectedBrotherPrinter == null && _brotherPrinters.isNotEmpty) {
        await selectBrotherPrinter(_brotherPrinters.first);
      }

    } catch (e) {
      debugPrint('❌ Brother printer discovery failed: $e');
      _handleBrotherError('Brother printer discovery failed: $e');
    } finally {
      _isDiscoveringBrotherPrinters = false;
      notifyListeners();
    }
  }

  /// Select Brother printer
  Future<void> selectBrotherPrinter(BrotherPrinter printer) async {
    try {
      debugPrint('🔗 Selecting Brother printer: ${printer.displayName}');
      
      // Disconnect from current printer if connected
      if (_activeBrotherConnection != null) {
        await _connectionManager.closeConnection(_activeBrotherConnection!.id);
      }

      _selectedBrotherPrinter = printer;
      notifyListeners();

      // Attempt connection
      await connectToBrotherPrinter();
      
    } catch (e) {
      debugPrint('❌ Failed to select Brother printer: $e');
      _handleBrotherError('Failed to select Brother printer: $e');
    }
  }

  /// Connect to selected Brother printer
  Future<void> connectToBrotherPrinter() async {
    if (_selectedBrotherPrinter == null) {
      _setError('No Brother printer selected');
      return;
    }

    try {
      debugPrint('🔗 Connecting to Brother printer: ${_selectedBrotherPrinter!.displayName}');
      
      // Check if MFi authentication is required
      if (_selectedBrotherPrinter!.isMfiCertified) {
        final authRequired = await _mfiService.isAuthenticationRequired(_selectedBrotherPrinter!);
        if (authRequired) {
          debugPrint('🔐 MFi authentication required');
          final authResult = await _mfiService.authenticate(_selectedBrotherPrinter!);
          if (!authResult.isSuccess) {
            throw Exception('MFi authentication failed: ${authResult.errorMessage}');
          }
          debugPrint('✅ MFi authentication successful');
        }
      }

      // Establish connection
      final connection = await _connectionManager.establishConnection(_selectedBrotherPrinter!);
      
      if (connection.isConnected) {
        _activeBrotherConnection = connection;
        
        // Connect Brother printer service
        await _brotherPrinterService.connectToPrinter(_selectedBrotherPrinter!.id);
        
        debugPrint('✅ Connected to Brother printer: ${_selectedBrotherPrinter!.displayName}');
        _clearError();
      } else {
        throw Exception('Failed to establish connection');
      }

    } catch (e) {
      debugPrint('❌ Brother printer connection failed: $e');
      _handleBrotherError('Brother printer connection failed: $e', context: {
        'printerId': _selectedBrotherPrinter?.id,
        'printerName': _selectedBrotherPrinter?.displayName,
        'connectionType': _selectedBrotherPrinter?.connectionType.toString(),
      });
      _activeBrotherConnection = null;
    } finally {
      notifyListeners();
    }
  }

  /// Disconnect from Brother printer
  Future<void> disconnectBrotherPrinter() async {
    try {
      if (_activeBrotherConnection != null) {
        await _connectionManager.closeConnection(_activeBrotherConnection!.id);
        await _brotherPrinterService.disconnect();
        _activeBrotherConnection = null;
        debugPrint('🔌 Disconnected from Brother printer');
      }
    } catch (e) {
      debugPrint('❌ Brother printer disconnection failed: $e');
    } finally {
      notifyListeners();
    }
  }

  /// Print badge using Brother printer
  Future<bool> printBadgeWithBrother({
    required Attendee attendee,
    String? eventName,
    JobPriority priority = JobPriority.normal,
  }) async {
    if (!hasBrotherConnection) {
      _setError('No Brother printer connected');
      return false;
    }

    try {
      debugPrint('🖨️ Printing badge with Brother printer for: ${attendee.fullName}');

      // Select the correct template based on VIP status
      await _selectTemplateForAttendee(attendee);
      if (_selectedTemplate == null) {
        _setError('No badge template selected');
        return false;
      }

      // Create badge data
      final badgeData = BadgeData(
        attendeeId: attendee.id,
        attendeeName: attendee.fullName,
        attendeeEmail: attendee.email,
        qrCode: attendee.qrCode,
        vipLogoUrl: attendee.vipLogoUrl,
        isVip: attendee.isVip,
        templateData: {
          'template': _selectedTemplate!.toJson(),
          'eventName': eventName,
        },
      );

      // Print using Brother service
      final result = await _brotherPrinterService.printBadge(badgeData);
      
      if (result.success) {
        await _markBadgeGenerated(attendee.id);
        debugPrint('✅ Badge printed successfully with Brother printer');
        return true;
      } else {
        _handleBrotherError('Brother printing failed: ${result.errorMessage}', 
          errorCode: result.errorCode,
          context: {
            'attendeeId': attendee.id,
            'attendeeName': attendee.fullName,
            'printerId': _selectedBrotherPrinter?.id,
          });
        return false;
      }

    } catch (e) {
      debugPrint('❌ Brother printing error: $e');
      _handleBrotherError('Brother printing error: $e', context: {
        'attendeeId': attendee.id,
        'attendeeName': attendee.fullName,
      });
      return false;
    }
  }

  /// Print multiple badges using Brother printer with queue management
  Future<bool> printMultipleBadgesWithBrother({
    required List<Attendee> attendees,
    String? eventName,
    JobPriority priority = JobPriority.normal,
  }) async {
    if (!hasBrotherConnection) {
      _setError('No Brother printer connected');
      return false;
    }

    if (attendees.isEmpty) {
      _setError('No attendees selected for printing');
      return false;
    }

    try {
      debugPrint('🖨️ Queuing ${attendees.length} badges for Brother printing');

      // Select template (assuming same template for all)
      await _selectTemplateForAttendee(attendees.first);
      if (_selectedTemplate == null) {
        _setError('No badge template selected');
        return false;
      }

      final jobIds = <String>[];

      // Create print jobs for each attendee
      for (final attendee in attendees) {
        try {
          final jobId = await _queueManager.addJob(
            job: PrintJob(
              id: '', // Will be generated by queue manager
              printerId: _selectedBrotherPrinter!.id,
              badgeData: BadgeData(
                attendeeId: attendee.id,
                attendeeName: attendee.fullName,
                attendeeEmail: attendee.email,
                qrCode: attendee.qrCode,
                vipLogoUrl: attendee.vipLogoUrl,
                isVip: attendee.isVip,
                templateData: {
                  'template': _selectedTemplate!.toJson(),
                  'eventName': eventName,
                },
              ),
              settings: PrintSettings(
                labelSize: LabelSize(
                  id: 'default',
                  name: 'Default Label',
                  widthMm: 62,
                  heightMm: 29,
                  isRoll: true,
                ),
                copies: 1,
                autoCut: true,
                quality: PrintQuality.normal,
              ),
              createdAt: DateTime.now(),
              priority: priority,
            ),
          );
          jobIds.add(jobId);
        } catch (e) {
          debugPrint('❌ Failed to queue job for ${attendee.fullName}: $e');
        }
      }

      debugPrint('✅ Queued ${jobIds.length}/${attendees.length} print jobs');
      
      // Mark badges as generated (they will be processed by the queue)
      for (final attendee in attendees) {
        await _markBadgeGenerated(attendee.id);
      }

      return jobIds.isNotEmpty;

    } catch (e) {
      debugPrint('❌ Brother batch printing error: $e');
      _handleBrotherError('Brother batch printing error: $e', context: {
        'attendeeCount': attendees.length,
        'printerId': _selectedBrotherPrinter?.id,
      });
      return false;
    }
  }

  /// Handle connection events
  void _handleConnectionEvent(ConnectionEvent event) {
    debugPrint('🔔 Connection event: ${event.type} for printer ${event.printerId}');
    
    switch (event.type) {
      case ConnectionEventType.connected:
        if (event.printerId == _selectedBrotherPrinter?.id) {
          _clearError();
        }
        break;
      case ConnectionEventType.disconnected:
        if (event.printerId == _selectedBrotherPrinter?.id) {
          _activeBrotherConnection = null;
        }
        break;
      case ConnectionEventType.error:
        if (event.printerId == _selectedBrotherPrinter?.id) {
          _setError('Connection error: ${event.data['error']}');
        }
        break;
      default:
        break;
    }
    
    notifyListeners();
  }

  /// Handle printer status updates
  void _handlePrinterStatusUpdate(PrinterStatus status) {
    debugPrint('🔔 Printer status update: $status');
    
    switch (status) {
      case PrinterStatus.disconnected:
        _activeBrotherConnection = null;
        break;
      case PrinterStatus.error:
        _setError('Printer error detected');
        break;
      case PrinterStatus.outOfLabels:
        _setError('Printer is out of labels');
        break;
      case PrinterStatus.lowBattery:
        _setError('Printer battery is low');
        break;
      default:
        _clearError();
        break;
    }
    
    notifyListeners();
  }

  /// Handle health monitoring updates
  void _handleHealthUpdate(HealthCheckResult result) {
    if (result.connectionId == _activeBrotherConnection?.id) {
      if (result.needsAttention) {
        debugPrint('⚠️ Connection health issue: ${result.errorMessage}');
      }
    }
  }

  /// Handle queue statistics updates
  void _handleQueueUpdate(QueueStatistics stats) {
    debugPrint('📊 Queue stats: ${stats.pendingJobs} pending, ${stats.processingJobs} processing');
    // Could update UI with queue information
  }

  /// Get Brother printer status
  String getBrotherPrinterStatus() {
    if (!_isBrotherPrintingEnabled) {
      return 'Brother printing not initialized';
    }
    
    if (_selectedBrotherPrinter == null) {
      return 'No Brother printer selected';
    }
    
    if (_activeBrotherConnection == null) {
      return 'Disconnected';
    }
    
    switch (_activeBrotherConnection!.status) {
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.error:
        return 'Connection Error';
      case ConnectionStatus.authenticating:
        return 'Authenticating...';
      default:
        return 'Disconnected';
    }
  }

  /// Get queue statistics
  QueueStatistics? getQueueStatistics() {
    try {
      return _queueManager.getStatistics();
    } catch (e) {
      return null;
    }
  }

  /// Test Brother printer connection
  Future<bool> testBrotherConnection() async {
    if (_activeBrotherConnection == null) {
      return false;
    }

    try {
      return await _connectionManager.testConnection(_activeBrotherConnection!.id);
    } catch (e) {
      debugPrint('❌ Brother connection test failed: $e');
      return false;
    }
  }

  /// Discover native printers (Brother, AirPrint, Bluetooth, WiFi)
  Future<void> discoverNativePrinters() async {
    _isDiscoveringPrinters = true;
    _clearError();
    notifyListeners();

    try {
      await _nativePrinterService.discoverPrinters();
      _discoveredPrinters = _nativePrinterService.availablePrinters;
    } catch (e) {
      _setError('Error discovering printers: ${e.toString()}');
    } finally {
      _isDiscoveringPrinters = false;
      notifyListeners();
    }
  }

  /// Select a native printer
  void selectNativePrinter(Map<String, dynamic>? printer) {
    _selectedNativePrinter = printer;
    if (printer != null) {
      _nativePrinterService.selectPrinter(printer['id'] ?? '');
    }
    notifyListeners();
  }

  /// Toggle native printing mode
  void setUseNativePrinting(bool useNative) {
    _useNativePrinting = useNative;
    notifyListeners();
  }

  /// Test print functionality
  Future<bool> testPrint({String? printerId}) async {
    _clearError();
    
    try {
      final success = await _nativePrinterService.testPrint(printerId: printerId);
      
      if (!success) {
        _setError('Test print failed. Please check your printer connection.');
      }
      
      return success;
    } catch (e) {
      _setError('Test print error: ${e.toString()}');
      return false;
    }
  }

  /// Get detailed printer information
  Map<String, dynamic>? getPrinterDetails(String printerId) {
    return _nativePrinterService.getPrinterDetails(printerId);
  }

  /// Get all discovered printers with detailed information
  List<Map<String, dynamic>> getAllPrintersWithDetails() {
    return _nativePrinterService.getAllPrintersWithDetails();
  }

  /// Check if a printer supports specific capabilities
  bool printerSupportsCapability(String printerId, String capability) {
    return _nativePrinterService.printerSupportsCapability(printerId, capability);
  }

  /// Print badge using native printer service (without dialogs)
  Future<bool> printBadgeNatively({
    required Attendee attendee,
    String? eventName,
    Map<String, dynamic>? printer,
  }) async {
    // Select the correct template based on VIP status
    await _selectTemplateForAttendee(attendee);
    if (_selectedTemplate == null) {
      _setError('No badge template selected');
      return false;
    }

    _clearError();

    try {
      // Check if "Download as PDF" printer is selected
      final targetPrinter = printer ?? _selectedNativePrinter;
      if (targetPrinter != null && targetPrinter['id'] == 'pdf_download') {
        print('📥 Auto-downloading PDF (native printing with PDF printer selected)');
        final filePath = await saveBadgeToDownloads(
          attendee: attendee,
          eventName: eventName,
        );
        return filePath != null;
      }
      
      final success = await _nativePrinterService.printBadgeDirectly(
        attendee: attendee,
        template: _selectedTemplate!,
        eventName: eventName ?? 'Event',
        printer: targetPrinter,
      );

      if (success) {
        // Mark badge as generated
        await _markBadgeGenerated(attendee.id);
        return true;
      } else {
        _setError('Failed to print badge');
        return false;
      }
    } catch (e) {
      _setError('Error printing badge: ${e.toString()}');
      return false;
    }
  }

  /// Print multiple badges using native printer service
  Future<bool> printMultipleBadgesNatively({
    required List<Attendee> attendees,
    String? eventName,
    Map<String, dynamic>? printer,
  }) async {
    if (attendees.isEmpty) {
      _setError('No attendees selected for printing');
      return false;
    }

    _clearError();

    try {
      // Check if "Download as PDF" printer is selected
      final targetPrinter = printer ?? _selectedNativePrinter;
      if (targetPrinter != null && targetPrinter['id'] == 'pdf_download') {
        print('📥 Auto-downloading multiple badges PDF (native printing with PDF printer selected)');
        final filePath = await saveMultipleBadgesToDownloads(
          attendees: attendees,
          eventName: eventName,
        );
        
        if (filePath != null) {
          // Show success message
          _showSuccessMessage('${attendees.length} PDFs saved successfully!\nLocation: $filePath');
          return true;
        } else {
          _showErrorMessage('Failed to save PDFs to Downloads folder');
          return false;
        }
      }
      
      // For real printers, print each badge individually
      int successCount = 0;
      for (final attendee in attendees) {
        final success = await printBadgeNatively(
          attendee: attendee,
          eventName: eventName,
          printer: printer,
        );
        if (success) successCount++;
      }

      if (successCount == attendees.length) {
        return true;
      } else {
        _setError('Printed $successCount of ${attendees.length} badges');
        return false;
      }
    } catch (e) {
      _setError('Error printing badges: ${e.toString()}');
      return false;
    }
  }

  /// Clear all data
  void clear() {
    _templates.clear();
    _selectedTemplate = null;
    _availablePrinters.clear();
    _selectedPrinter = null;
    _discoveredPrinters.clear();
    _selectedNativePrinter = null;
    _eventCache.clear();
    _clearError();
    notifyListeners();
  }

  /// Debug method to check current state
  void debugCurrentState() {
    print('🔍 BADGE PROVIDER DEBUG STATE:');
    print('📋 Templates loaded: ${_templates.length}');
    for (final template in _templates) {
      print('  - ${template.name} (${template.id}) - ${template.isVipTemplate ? "VIP" : "Regular"}');
    }
    print('📦 Cached events: ${_eventCache.length}');
    for (final entry in _eventCache.entries) {
      final event = entry.value;
      print('  - ${event.name} (${event.id})');
      print('    Regular template: ${event.regularBadgeTemplateId ?? "none"}');
      print('    VIP template: ${event.vipBadgeTemplateId ?? "none"}');
    }
    print('🎯 Selected template: ${_selectedTemplate?.name ?? "none"}');
    print('👤 Selected attendee: none (not stored in BadgeProvider)');
    print('❌ Error: ${_errorMessage ?? "none"}');
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }


}