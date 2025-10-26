import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/attendee.dart';
import '../models/badge_template.dart';

class BadgePrintingService {
  static const double _dpi = 300.0;
  static const double _mmToPoints = 2.834645669;
  static const double _pxToMm = 0.264583333; // 1px = 0.264583333mm at 96dpi
  static const double _inchToMm = 25.4; // 1 inch = 25.4mm
  
  // Cache for loaded fonts
  static pw.Font? _unicodeFont;

  /// Convert dimensions from various units to millimeters
  static double _convertToMm(double value, String unit) {
    switch (unit.toLowerCase()) {
      case 'px':
        return value * _pxToMm;
      case 'in':
      case 'inch':
        return value * _inchToMm;
      case 'mm':
      default:
        return value;
    }
  }

  /// Convert millimeters to points for PDF
  static double mmToPoints(double mm) {
    return mm * _mmToPoints;
  }

  /// Calculate scale factor: field coordinates are in pixels on a canvas
  /// that displays the badge at a certain scale
  static double _calculateFieldScale(double badgeDimensionInches) {
    // Web canvas typically displays at 96 DPI
    // So a 3.5" badge = 336 pixels on canvas
    const double webCanvasDpi = 96.0;
    return badgeDimensionInches * webCanvasDpi;
  }

  /// Load a Unicode-compatible font
  static Future<pw.Font?> _loadUnicodeFont() async {
    if (_unicodeFont != null) return _unicodeFont;
    
    try {
      // Try to load a system font that supports Unicode better than Helvetica
      final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      _unicodeFont = pw.Font.ttf(fontData);
      print('✅ FONT: Loaded Roboto font for Unicode support');
      return _unicodeFont;
    } catch (e) {
      print('⚠️ FONT: Failed to load Roboto from assets, trying system font: $e');
      try {
        // Fallback to a system font through printing package
        final fontData = await rootBundle.load('packages/printing/fonts/roboto/Roboto-Regular.ttf');
        _unicodeFont = pw.Font.ttf(fontData);
        print('✅ FONT: Loaded system Roboto font as fallback');
        return _unicodeFont;
      } catch (e2) {
        print('❌ FONT: Failed to load any Unicode font, will use default: $e2');
        return null;
      }
    }
  }

  /// Download image from URL and convert to PDF image
  static Future<pw.ImageProvider?> _downloadImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    
    try {
      // Handle relative URLs by converting to absolute URLs
      String fullUrl;
      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        fullUrl = imageUrl;
      } else if (imageUrl.startsWith('/')) {
        // Relative path starting with /, assume it's from the remote backend
        fullUrl = 'https://lightslategray-donkey-866736.hostingersite.com$imageUrl';
      } else {
        // Relative path, assume it's from the remote backend
        fullUrl = 'https://lightslategray-donkey-866736.hostingersite.com/$imageUrl';
      }
      
      print('🖼️ Downloading image from: $fullUrl');
      
      // Use the proxy-image endpoint to bypass CORS
      const String proxyUrl = 'https://lightslategray-donkey-866736.hostingersite.com/proxy-image';
      
      final response = await http.post(
        Uri.parse(proxyUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'url': fullUrl}),
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['dataUrl'] != null) {
          // Extract base64 data from data URL
          final dataUrl = responseData['dataUrl'] as String;
          final base64Data = dataUrl.split(',')[1];
          final imageBytes = base64Decode(base64Data);
          
          print('🖼️ Image downloaded successfully via proxy (${imageBytes.length} bytes)');
          return pw.MemoryImage(imageBytes);
        } else {
          print('❌ No dataUrl in proxy response');
        }
      } else {
        print('❌ Failed to download image via proxy: HTTP ${response.statusCode}');
        print('❌ Response body: ${response.body}');
      }
    } catch (e) {
      print('❌ Error downloading image from $imageUrl: $e');
    }
    return null;
  }

  /// Generate a badge PDF for an attendee using the specified template
  static Future<Uint8List> generateBadgePdf({
    required Attendee attendee,
    required BadgeTemplate template,
    String? eventName,
  }) async {
    final pdf = pw.Document();

    // Comprehensive logging for template info
    print('🎨 BADGE GENERATION: Template "${template.name}" (${template.id})');
    print('📏 Dimensions: ${template.width}x${template.height} ${template.dimensions['units'] ?? 'in'}');
    print('🖼️ Background: ${template.logoUrl ?? "none"}');
    print('📋 Fields: ${template.fields.length}');

    // Log each field
    for (int i = 0; i < template.fields.length; i++) {
      final field = template.fields[i];
      print('📌 Field ${field.id}: ${field.type}');
      print('   Content: "${field.content}"');
      print('   Position: (${field.x}, ${field.y})');
      print('   Size: ${field.width} x ${field.height}');
      
      if (field.type == 'text') {
        String content = _getFieldContent(field, attendee, eventName);
        print('   ✏️ Resolved: "$content"');
      }
    }

    // Get dimensions from template, with fallback to defaults
    final dimensions = template.dimensions;
    final widthInches = (dimensions['width'] ?? 400).toDouble();
    final heightInches = (dimensions['height'] ?? 300).toDouble();
    final units = (dimensions['units'] as String?) ?? 'in'; // Badge dimensions are in inches

    print('🔍 BADGE PRINTING: Raw dimensions: ${widthInches}x${heightInches} units: $units');

    // Calculate template pixel dimensions (matching web app logic)
    final templatePixelWidth = widthInches * 96.0; // 96 DPI
    final templatePixelHeight = heightInches * 96.0;

    print('🔍 BADGE PRINTING: Template pixel dimensions: ${templatePixelWidth}px x ${templatePixelHeight}px');

    // Calculate canvas display scale (matching web app exactly: maxDisplayWidth: 500, maxDisplayHeight: 600)
    final maxDisplayWidth = 500.0;
    final maxDisplayHeight = 600.0;
    final scaleX = maxDisplayWidth / templatePixelWidth;
    final scaleY = maxDisplayHeight / templatePixelHeight;
    final canvasDisplayScale = math.min(math.min(scaleX, scaleY), 1.0); // Don't scale up, only down (matching web app)

    print('🔍 BADGE PRINTING: Canvas display scale: $canvasDisplayScale (scaleX: $scaleX, scaleY: $scaleY)');
    print('🔍 BADGE PRINTING: Max display: ${maxDisplayWidth}px x ${maxDisplayHeight}px');

    // Convert dimensions to millimeters
    final widthMm = _convertToMm(widthInches, units);
    final heightMm = _convertToMm(heightInches, units);

    print('🔍 BADGE PRINTING: Converted dimensions: ${widthMm}mm x ${heightMm}mm');

    // Validate and fix template dimensions
    final validatedWidth = widthMm > 0 ? widthMm : 85.6; // Default credit card width
    final validatedHeight = heightMm > 0 ? heightMm : 53.98; // Default credit card height

    // Convert template dimensions from mm to points
    final pageWidth = mmToPoints(validatedWidth);
    final pageHeight = mmToPoints(validatedHeight);

    // Additional validation for PDF page format
    if (pageWidth <= 0 || pageHeight <= 0) {
      throw Exception('Invalid badge template dimensions: width=$validatedWidth, height=$validatedHeight');
    }

    // Pre-load images with error handling
    pw.ImageProvider? backgroundImage;
    if (template.hasBackgroundImage) {
      print('🖼️ Loading background image: ${template.backgroundImageUrl}');
      backgroundImage = await _downloadImage(template.backgroundImageUrl);
      print('🖼️ Background image ${backgroundImage != null ? "loaded successfully" : "failed to load"}');
    }

    pw.ImageProvider? logoImage;
    if (template.logoUrl != null && template.logoUrl!.isNotEmpty) {
      print('🏷️ Loading logo image: ${template.logoUrl}');
      logoImage = await _downloadImage(template.logoUrl);
      print('🏷️ Logo image ${logoImage != null ? "loaded successfully" : "failed to load"}');
    }

    // Pre-load VIP logo if attendee is VIP
    pw.ImageProvider? vipLogoImage;
    if (attendee.isVip && attendee.vipLogoUrl != null && attendee.vipLogoUrl!.isNotEmpty) {
      print('👑 Loading VIP logo: ${attendee.vipLogoUrl}');
      vipLogoImage = await _downloadImage(attendee.vipLogoUrl);
      print('👑 VIP logo ${vipLogoImage != null ? "loaded successfully" : "failed to load"}');
    }

    // Create PDF page with EXACT badge dimensions (no extra canvas space)
    print('🔍 BADGE PRINTING: PDF page size: ${validatedWidth}mm x ${validatedHeight}mm (exact badge size)');
    print('🔍 BADGE PRINTING: Badge positioned at: (0mm, 0mm) - fills entire page');

    // Build badge content asynchronously before adding to PDF
    final badgeContent = await _buildBadgeContentAsync(
      attendee: attendee,
      template: template,
      eventName: eventName,
      validatedWidth: validatedWidth,
      validatedHeight: validatedHeight,
      backgroundImage: backgroundImage,
      logoImage: logoImage,
      vipLogoImage: vipLogoImage,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(mmToPoints(validatedWidth), mmToPoints(validatedHeight)),
        margin: const pw.EdgeInsets.all(0),
        build: (pw.Context context) {
          return badgeContent;
        },
      ),
    );

    return pdf.save();
  }

  /// Generate multiple badges PDF for a list of attendees
  static Future<Uint8List> generateMultipleBadgesPdf({
    required List<Attendee> attendees,
    required BadgeTemplate template,
    String? eventName,
    int badgesPerPage = 1,
  }) async {
    final pdf = pw.Document();

    // Get dimensions from template, with fallback to defaults
    final dimensions = template.dimensions;
    final width = (dimensions['width'] ?? 400).toDouble();
    final height = (dimensions['height'] ?? 300).toDouble();
    final units = (dimensions['units'] as String?) ?? 'in'; // Badge dimensions are in inches

    print('🔍 BADGE PRINTING: Raw dimensions: ${width}x${height} units: $units');

    // Convert dimensions to millimeters
    final widthMm = _convertToMm(width, units);
    final heightMm = _convertToMm(height, units);

    print('🔍 BADGE PRINTING: Converted dimensions: ${widthMm}mm x ${heightMm}mm');

    // Validate and fix template dimensions
    final validatedWidth = widthMm > 0 ? widthMm : 85.6; // Default credit card width
    final validatedHeight = heightMm > 0 ? heightMm : 53.98; // Default credit card height

    // Convert template dimensions from mm to points
    final badgeWidth = mmToPoints(validatedWidth);
    final badgeHeight = mmToPoints(validatedHeight);

    // Additional validation for PDF page format
    if (badgeWidth <= 0 || badgeHeight <= 0) {
      throw Exception('Invalid badge template dimensions: width=$validatedWidth, height=$validatedHeight');
    }

    // Pre-load images with error handling
    pw.ImageProvider? backgroundImage;
    if (template.hasBackgroundImage) {
      print('🖼️ Loading background image: ${template.backgroundImageUrl}');
      backgroundImage = await _downloadImage(template.backgroundImageUrl);
      print('🖼️ Background image ${backgroundImage != null ? "loaded successfully" : "failed to load"}');
    }

    pw.ImageProvider? logoImage;
    if (template.logoUrl != null && template.logoUrl!.isNotEmpty) {
      print('🏷️ Loading logo image: ${template.logoUrl}');
      logoImage = await _downloadImage(template.logoUrl);
      print('🏷️ Logo image ${logoImage != null ? "loaded successfully" : "failed to load"}');
    }

    // Calculate page layout
    final pageFormat = PdfPageFormat.a4;
    final margin = 20.0;
    final spacing = 10.0;

    final availableWidth = pageFormat.width - (2 * margin);
    final availableHeight = pageFormat.height - (2 * margin);

    final badgesPerRow = (availableWidth / (badgeWidth + spacing)).floor();
    final badgesPerColumn = (availableHeight / (badgeHeight + spacing)).floor();
    final actualBadgesPerPage = badgesPerRow * badgesPerColumn;

    // Group attendees by page
    for (int i = 0; i < attendees.length; i += actualBadgesPerPage) {
      final pageAttendees = attendees.skip(i).take(actualBadgesPerPage).toList();
      
      // Build page content asynchronously before adding to PDF
      final pageContent = await _buildMultipleBadgesContentAsync(
        attendees: pageAttendees,
        template: template,
        eventName: eventName,
        badgesPerRow: badgesPerRow,
        badgeWidth: badgeWidth,
        badgeHeight: badgeHeight,
        spacing: spacing,
        validatedWidth: validatedWidth,
        validatedHeight: validatedHeight,
        backgroundImage: backgroundImage,
        logoImage: logoImage,
      );
      
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(margin),
          build: (pw.Context context) {
            return pageContent;
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Print a badge directly to the default printer
  static Future<bool> printBadge({
    required Attendee attendee,
    required BadgeTemplate template,
    String? eventName,
    String? printerName,
  }) async {
    try {
      final pdfData = await generateBadgePdf(
        attendee: attendee,
        template: template,
        eventName: eventName,
      );

      // For direct printing without context, use the default printer
      // If a specific printer is needed, it should be passed via printerName
      if (printerName != null) {
        final printer = Printer(url: printerName);
        await Printing.directPrintPdf(
          printer: printer,
          onLayout: (PdfPageFormat format) async => pdfData,
        );
      } else {
        // Use default printing without picker
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfData,
        );
      }

      return true;
    } catch (e) {
      print('Error printing badge: $e');
      return false;
    }
  }

  /// Show print preview dialog
  static Future<void> showPrintPreview({
    required BuildContext context,
    required Attendee attendee,
    required BadgeTemplate template,
    String? eventName,
  }) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) => generateBadgePdf(
        attendee: attendee,
        template: template,
        eventName: eventName,
      ),
      name: 'Badge_${attendee.fullName.replaceAll(' ', '_')}',
    );
  }

  /// Generate QR code image data
  static Future<Uint8List> generateQrCodeImage(String data, {double size = 200}) async {
    final qrValidationResult = QrValidator.validate(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    );

    if (qrValidationResult.status != QrValidationStatus.valid) {
      throw Exception('Invalid QR code data');
    }

    final qrCode = qrValidationResult.qrCode!;
    final painter = QrPainter.withQr(
      qr: qrCode,
      color: const Color(0xFF000000),
      emptyColor: const Color(0xFFFFFFFF),
      gapless: false,
    );

    final picData = await painter.toImageData(size, format: ui.ImageByteFormat.png);
    return picData!.buffer.asUint8List();
  }

  /// Build badge content for PDF (async version)
  static Future<pw.Widget> _buildBadgeContentAsync({
    required Attendee attendee,
    required BadgeTemplate template,
    String? eventName,
    required double validatedWidth,
    required double validatedHeight,
    pw.ImageProvider? backgroundImage,
    pw.ImageProvider? logoImage,
    pw.ImageProvider? vipLogoImage,
  }) async {
    print('🔍 BADGE PRINTING: Building badge for ${attendee.fullName}');
    print('🔍 BADGE PRINTING: Template "${template.name}" has ${template.fields.length} fields');
    print('🔍 BADGE PRINTING: Badge dimensions: ${validatedWidth}mm x ${validatedHeight}mm');
    print('🔍 BADGE PRINTING: Background color: ${template.backgroundColor}');
    print('🔍 BADGE PRINTING: Background image: ${backgroundImage != null ? "loaded" : "none"}');
    print('🔍 BADGE PRINTING: Logo image: ${logoImage != null ? "loaded" : "none"}');
    print('🔍 BADGE PRINTING: VIP logo image: ${vipLogoImage != null ? "loaded" : "none"}');
    print('🔍 BADGE PRINTING: Attendee VIP status: ${attendee.isVip}');
    print('🔍 BADGE PRINTING: Attendee VIP logo URL: ${attendee.vipLogoUrl}');
    
    // Calculate field scaling based on badge dimensions (matching web app logic)
    final dimensions = template.dimensions;
    final widthInches = (dimensions['width'] ?? 400).toDouble();
    final heightInches = (dimensions['height'] ?? 300).toDouble();
    
    // Calculate template pixel dimensions (matching web app logic)
    final templatePixelWidth = widthInches * 96.0; // 96 DPI
    final templatePixelHeight = heightInches * 96.0;
    
    // Calculate canvas display scale (matching web app: maxDisplayWidth: 500, maxDisplayHeight: 600)
    final scaleX = 500.0 / templatePixelWidth;
    final scaleY = 600.0 / templatePixelHeight;
    final canvasDisplayScale = math.min(scaleX, math.min(scaleY, 1.0));
    
    print('🔍 BADGE PRINTING: Template pixel dimensions: ${templatePixelWidth}px x ${templatePixelHeight}px');
    print('🔍 BADGE PRINTING: Canvas display scale: $canvasDisplayScale');
    
    // Log each field being rendered with detailed information
    for (int i = 0; i < template.fields.length; i++) {
      final field = template.fields[i];
      print('🔍 BADGE PRINTING: Field $i: ${field.type} "${field.content}" at (${field.x}, ${field.y}) size (${field.width}, ${field.height})');
      print('🔍 BADGE PRINTING: Field $i style: fontSize=${field.fontSize}, fontWeight=${field.fontWeight}, color=${field.color}, textAlign=${field.textAlign}');
      
      // For text fields, show what the resolved content will be
      if (field.type == 'text') {
        final resolvedContent = _getFieldContent(field, attendee, eventName);
        print('🔍 BADGE PRINTING: Field $i resolved content: "$resolvedContent"');
      }
    }
    
    if (template.fields.isEmpty) {
      print('⚠️ BADGE PRINTING: Template has no fields - will render blank badge!');
    }
    
    // Apply background settings
    pw.BoxFit backgroundFit = pw.BoxFit.cover;
    if (template.backgroundSettings != null) {
      final size = template.backgroundSettings!['size'] as String?;
      if (size != null) {
        switch (size.toLowerCase()) {
          case 'contain':
            backgroundFit = pw.BoxFit.contain;
            break;
          case 'fill':
            backgroundFit = pw.BoxFit.fill;
            break;
          case 'fitwidth':
            backgroundFit = pw.BoxFit.fitWidth;
            break;
          case 'fitheight':
            backgroundFit = pw.BoxFit.fitHeight;
            break;
          case 'none':
            backgroundFit = pw.BoxFit.none;
            break;
          default:
            backgroundFit = pw.BoxFit.cover;
        }
      }
    }

    return pw.Container(
      width: mmToPoints(validatedWidth),
      height: mmToPoints(validatedHeight),
      decoration: pw.BoxDecoration(
        color: _parseColor(template.backgroundColor),
        image: backgroundImage != null ? pw.DecorationImage(
          image: backgroundImage,
          fit: backgroundFit,
        ) : null,
      ),
      child: pw.Stack(
        children: await Future.wait(template.fields.map((field) async {
          print('🔍 FIELD POSITIONING: Processing field "${field.id}" (${field.type})');
          
          // Two-step coordinate conversion (matching web app logic)
          // Step 1: Convert field coordinates from canvas display coordinates to template coordinates
          final fieldPosX = field.x / canvasDisplayScale;
          final fieldPosY = field.y / canvasDisplayScale;
          final fieldSizeWidth = field.width / canvasDisplayScale;
          final fieldSizeHeight = field.height / canvasDisplayScale;
          
          print('🔍 FIELD POSITIONING: Field ${field.type} - Original: (${field.x}, ${field.y}) size (${field.width}, ${field.height})');
          print('🔍 FIELD POSITIONING: Field ${field.type} - Scaled: ($fieldPosX, $fieldPosY) size ($fieldSizeWidth, $fieldSizeHeight)');
          
          // Step 2: Calculate proportional position within the badge (convert to PDF coordinates in mm)
          // This matches the web app logic exactly
          final fieldXMm = (fieldPosX / templatePixelWidth) * validatedWidth;
          final fieldYMm = (fieldPosY / templatePixelHeight) * validatedHeight;
          final fieldWidthMm = (fieldSizeWidth / templatePixelWidth) * validatedWidth;
          final fieldHeightMm = (fieldSizeHeight / templatePixelHeight) * validatedHeight;
          
          // CRITICAL FIX: Ensure minimum field dimensions for text visibility
          // Text fields need adequate height to be visible
          final minFieldHeightMm = field.type == 'text' ? 15.0 : 2.0; // 15mm minimum for text fields (increased from 8mm)
          final minFieldWidthMm = field.type == 'text' ? 20.0 : 2.0; // 20mm minimum for text fields (increased from 10mm)
          final adjustedFieldHeightMm = math.max(fieldHeightMm, minFieldHeightMm);
          final adjustedFieldWidthMm = math.max(fieldWidthMm, minFieldWidthMm);
          
          if (fieldHeightMm < minFieldHeightMm) {
            print('⚠️ FIELD DIMENSIONS: Field height ${fieldHeightMm.toStringAsFixed(2)}mm too small, adjusting to ${adjustedFieldHeightMm.toStringAsFixed(2)}mm');
          }
          if (fieldWidthMm < minFieldWidthMm) {
            print('⚠️ FIELD DIMENSIONS: Field width ${fieldWidthMm.toStringAsFixed(2)}mm too small, adjusting to ${adjustedFieldWidthMm.toStringAsFixed(2)}mm');
          }
          
          print('🔍 FIELD POSITIONING: Field ${field.type} - Final PDF: ($fieldXMm, $fieldYMm) size ($adjustedFieldWidthMm, $adjustedFieldHeightMm) mm');
          print('🔍 FIELD POSITIONING: Field ${field.type} - Final PDF points: (${mmToPoints(fieldXMm)}, ${mmToPoints(fieldYMm)}) size (${mmToPoints(adjustedFieldWidthMm)}, ${mmToPoints(adjustedFieldHeightMm)})');
          
          return pw.Positioned(
            left: mmToPoints(fieldXMm),
            top: mmToPoints(fieldYMm),
            child: pw.Container(
              width: mmToPoints(adjustedFieldWidthMm),
              height: mmToPoints(adjustedFieldHeightMm),
              child: await _buildFieldWidget(field, attendee, eventName, logoImage, vipLogoImage, canvasDisplayScale),
            ),
          );
        })),
      ),
    );
  }

  /// Build multiple badges content for PDF (async version)
  static Future<pw.Widget> _buildMultipleBadgesContentAsync({
    required List<Attendee> attendees,
    required BadgeTemplate template,
    String? eventName,
    required int badgesPerRow,
    required double badgeWidth,
    required double badgeHeight,
    required double spacing,
    required double validatedWidth,
    required double validatedHeight,
    pw.ImageProvider? backgroundImage,
    pw.ImageProvider? logoImage,
  }) async {
    final rows = <pw.Widget>[];
    
    for (int i = 0; i < attendees.length; i += badgesPerRow) {
      final rowAttendees = attendees.skip(i).take(badgesPerRow).toList();
      
      final rowChildren = await Future.wait(rowAttendees.map((attendee) async {
        return pw.Container(
          width: badgeWidth,
          height: badgeHeight,
          margin: pw.EdgeInsets.only(right: spacing, bottom: spacing),
          child: await _buildBadgeContentAsync(
            attendee: attendee,
            template: template,
            eventName: eventName,
            validatedWidth: validatedWidth,
            validatedHeight: validatedHeight,
            backgroundImage: backgroundImage,
            logoImage: logoImage,
            vipLogoImage: null, // For multiple badges, VIP logos would need to be handled differently
          ),
        );
      }));
      
      rows.add(
        pw.Row(
          children: rowChildren,
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: rows,
    );
  }

  /// Build individual field widget for PDF
  static Future<pw.Widget> _buildFieldWidget(BadgeField field, Attendee attendee, String? eventName, pw.ImageProvider? logoImage, pw.ImageProvider? vipLogoImage, double canvasDisplayScale) async {
    print('🔍 FIELD WIDGET: Building ${field.type} field "${field.id}"');
    
    switch (field.type) {
      case 'text':
        final content = _getFieldContent(field, attendee, eventName);
        print('🔍 FIELD WIDGET: Text field content: "$content"');
        return await _buildTextField(field, attendee, eventName, canvasDisplayScale);
      case 'qr':
        print('🔍 FIELD WIDGET: QR field data: "${attendee.qrCode}"');
        return _buildQrField(field, attendee);
      case 'image':
        print('🔍 FIELD WIDGET: Image field');
        return _buildImageField(field);
      case 'logo':
        print('🔍 FIELD WIDGET: Logo field, logo available: ${logoImage != null}');
        print('🔍 FIELD WIDGET: Attendee VIP status: ${attendee.isVip}');
        print('🔍 FIELD WIDGET: Attendee VIP logo URL: ${attendee.vipLogoUrl}');
        print('🔍 FIELD WIDGET: VIP logo image loaded: ${vipLogoImage != null}');
        
        // Check if this is for a VIP attendee with a VIP logo
        if (attendee.isVip && attendee.vipLogoUrl != null && attendee.vipLogoUrl!.isNotEmpty) {
          print('🔍 FIELD WIDGET: Using VIP-specific logo: ${attendee.vipLogoUrl}');
          return _buildVipLogoField(field, attendee, vipLogoImage);
        } else {
          print('🔍 FIELD WIDGET: Using regular template logo');
          return _buildLogoField(field, logoImage);
        }
      default:
        print('⚠️ FIELD WIDGET: Unknown field type: ${field.type}');
        return pw.Container();
    }
  }

  /// Build text field widget with proper overflow handling and line wrapping
  static Future<pw.Widget> _buildTextField(BadgeField field, Attendee attendee, String? eventName, double canvasDisplayScale) async {
    String content = _getFieldContent(field, attendee, eventName);
    
    // Load Unicode font for better text rendering
    final unicodeFont = await _loadUnicodeFont();
    
    // CRITICAL FIX: Apply canvas display scale to font size to match web app behavior
    // The web app scales font sizes based on the canvas display scale
    final baseFontSize = field.fontSize;
    final scaledFontSize = baseFontSize * canvasDisplayScale;
    
    print('🔍 FONT SCALING: Field "${field.id}" - Base: ${baseFontSize}px, Scale: ${canvasDisplayScale.toStringAsFixed(3)}, Final: ${scaledFontSize.toStringAsFixed(1)}px');
    
    // Only apply fontWeight if it's not bold to avoid Unicode warning
    pw.FontWeight? fontWeight;
    if (field.fontWeight.toLowerCase() != 'bold') {
      fontWeight = _parseFontWeight(field.fontWeight);
    }
    
    // Calculate field dimensions in points for text fitting
    final fieldWidthPx = field.width.toDouble();
    final fieldHeightPx = field.height.toDouble();
    
    print('🔍 TEXT FITTING: Field dimensions: ${fieldWidthPx}px x ${fieldHeightPx}px');
    
    // Remove any manual newlines and let the text wrap naturally
    final cleanContent = content.replaceAll('\n', ' ').trim();
    print('🔍 TEXT PROCESSING: Original: "$content" -> Clean: "$cleanContent"');
    
    // Use automatic text wrapping with dynamic height calculation
    return _buildFittedText(
      cleanContent,
      scaledFontSize,
      fieldWidthPx,
      fieldHeightPx,
      unicodeFont,
      _parseColor(field.color),
      fontWeight,
      _parseTextAlign(field.textAlign),
    );
  }

  /// Build text that fits within the specified dimensions with automatic wrapping and scaling
  static pw.Widget _buildFittedText(
    String text,
    double fontSize,
    double maxWidth,
    double maxHeight,
    pw.Font? font,
    PdfColor color,
    pw.FontWeight? fontWeight,
    pw.TextAlign textAlign,
  ) {
    // Apply padding similar to web app (90% of available width)
    final effectiveMaxWidth = maxWidth * 0.9;
    
    print('🔍 TEXT FITTING: Text "$text" - MaxWidth: ${effectiveMaxWidth.toStringAsFixed(1)}px, MaxHeight: ${maxHeight.toStringAsFixed(1)}px');
    
    // Estimate text width (improved approximation)
    final estimatedCharWidth = fontSize * 0.55; // More accurate character width estimation
    final estimatedTextWidth = text.length * estimatedCharWidth;
    
    print('🔍 TEXT FITTING: Estimated text width: ${estimatedTextWidth.toStringAsFixed(1)}px');
    
    // Check if text needs wrapping or scaling
    if (estimatedTextWidth > effectiveMaxWidth) {
      print('🔍 TEXT FITTING: Text exceeds width, applying wrapping/scaling');
      
      // Try to wrap text first
      final words = text.split(' ');
      if (words.length > 1) {
        // Multi-word text - try wrapping
        final wrappedLines = _wrapTextToLines(text, effectiveMaxWidth, estimatedCharWidth);
        
        if (wrappedLines.length > 1) {
          print('🔍 TEXT FITTING: Wrapped into ${wrappedLines.length} lines');
          
          // Calculate font size to fit all lines in available height
          final lineHeight = fontSize * 1.2; // Line height with proper spacing
          final totalTextHeight = wrappedLines.length * lineHeight;
          
          double adjustedFontSize = fontSize;
          if (totalTextHeight > maxHeight) {
            // Allow some flexibility in height - use 80% of max height for better fit
            adjustedFontSize = (maxHeight * 0.8) / (wrappedLines.length * 1.2);
            print('🔍 TEXT FITTING: Adjusted font size to ${adjustedFontSize.toStringAsFixed(1)}px to fit height');
          }
          
          // Ensure minimum readable font size
          adjustedFontSize = math.max(adjustedFontSize, fontSize * 0.6);
          
          print('🔍 TEXT FITTING: Final font size: ${adjustedFontSize.toStringAsFixed(1)}px for ${wrappedLines.length} lines');
          print('🔍 TEXT FITTING: Lines: ${wrappedLines.join(" | ")}');
          
          return pw.Container(
            width: effectiveMaxWidth,
            child: pw.Column(
              crossAxisAlignment: _parseTextAlignToCrossAxis(_textAlignToString(textAlign)),
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: wrappedLines.map((line) => pw.Text(
                line.trim(),
                style: pw.TextStyle(
                  fontSize: adjustedFontSize,
                  color: color,
                  fontWeight: fontWeight,
                  font: font,
                ),
                textAlign: textAlign,
              )).toList(),
            ),
          );
        }
      }
      
      // Single word or wrapping didn't help - scale down font size
      final scaleFactor = effectiveMaxWidth / estimatedTextWidth;
      final adjustedFontSize = fontSize * scaleFactor;
      
      print('🔍 TEXT FITTING: Scaling font size to ${adjustedFontSize.toStringAsFixed(1)}px (scale: ${scaleFactor.toStringAsFixed(2)})');
      print('🔍 TEXT STYLE: fontSize=$adjustedFontSize, color=$color, fontWeight=$fontWeight, font=${font != null ? "loaded" : "null"}');
      
      return pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: adjustedFontSize,
          color: color,
          fontWeight: fontWeight,
          font: font,
        ),
        textAlign: textAlign,
      );
    }
    
    // Text fits as-is
    print('🔍 TEXT FITTING: Text fits without modification');
    print('🔍 TEXT STYLE: fontSize=$fontSize, color=$color, fontWeight=$fontWeight, font=${font != null ? "loaded" : "null"}');
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
        font: font,
      ),
      textAlign: textAlign,
    );
  }

  /// Wrap text into multiple lines based on available width
  static List<String> _wrapTextToLines(String text, double maxWidth, double charWidth) {
    final words = text.split(' ');
    final lines = <String>[];
    String currentLine = '';
    
    for (final word in words) {
      final testLine = currentLine.isEmpty ? word : '$currentLine $word';
      final estimatedWidth = testLine.length * charWidth;
      
      if (estimatedWidth <= maxWidth) {
        currentLine = testLine;
      } else {
        if (currentLine.isNotEmpty) {
          lines.add(currentLine);
          currentLine = word;
        } else {
          // Single word is too long, try to break it
          if (word.length > 10) {
            // For very long words, try to break them
            final brokenWord = _breakLongWord(word, maxWidth, charWidth);
            lines.addAll(brokenWord);
          } else {
            lines.add(word);
          }
        }
      }
    }
    
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }
    
    return lines.isEmpty ? [text] : lines;
  }

  /// Break a long word into multiple lines
  static List<String> _breakLongWord(String word, double maxWidth, double charWidth) {
    final lines = <String>[];
    final maxCharsPerLine = (maxWidth / charWidth).floor();
    
    if (word.length <= maxCharsPerLine) {
      return [word];
    }
    
    int start = 0;
    while (start < word.length) {
      int end = (start + maxCharsPerLine).clamp(0, word.length);
      lines.add(word.substring(start, end));
      start = end;
    }
    
    return lines;
  }

  /// Convert TextAlign to string for cross-axis alignment
  static String _textAlignToString(pw.TextAlign textAlign) {
    switch (textAlign) {
      case pw.TextAlign.center:
        return 'center';
      case pw.TextAlign.right:
        return 'right';
      case pw.TextAlign.left:
      default:
        return 'left';
    }
  }

  /// Build QR code field widget
  static pw.Widget _buildQrField(BadgeField field, Attendee attendee) {
    return pw.Container(
      child: pw.BarcodeWidget(
        barcode: pw.Barcode.qrCode(),
        data: attendee.qrCode,
      ),
    );
  }

  /// Build image field widget
  static pw.Widget _buildImageField(BadgeField field) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Center(
        child: pw.Text(
          'Image',
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey,
          ),
        ),
      ),
    );
  }

  /// Build logo field widget
  static pw.Widget _buildLogoField(BadgeField field, pw.ImageProvider? logoImage) {
    if (logoImage == null) {
      return pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Center(
          child: pw.Text(
            'Logo',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey,
            ),
          ),
        ),
      );
    }

    return pw.Container(
      child: pw.Image(
        logoImage,
        fit: pw.BoxFit.contain,
      ),
    );
  }

  /// Build VIP logo field widget for attendee-specific VIP logos
  static pw.Widget _buildVipLogoField(BadgeField field, Attendee attendee, pw.ImageProvider? vipLogoImage) {
    print('🔍 VIP LOGO FIELD: Building VIP logo field for ${attendee.fullName}');
    print('🔍 VIP LOGO FIELD: Attendee VIP logo URL: ${attendee.vipLogoUrl}');
    print('🔍 VIP LOGO FIELD: VIP logo image provided: ${vipLogoImage != null}');
    
    if (attendee.vipLogoUrl == null || attendee.vipLogoUrl!.isEmpty) {
      print('⚠️ VIP LOGO FIELD: No VIP logo URL for attendee, showing placeholder');
      return pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Center(
          child: pw.Text(
            'VIP',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey,
            ),
          ),
        ),
      );
    }

    if (vipLogoImage == null) {
      print('❌ VIP LOGO FIELD: VIP logo image failed to load, showing placeholder');
      return pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Center(
          child: pw.Text(
            'VIP',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey,
            ),
          ),
        ),
      );
    }

    print('✅ VIP LOGO FIELD: Successfully rendering VIP logo image');
    return pw.Container(
      child: pw.Image(
        vipLogoImage,
        fit: pw.BoxFit.contain,
      ),
    );
  }

  /// Get content for a field based on field content and attendee data
  static String _getFieldContent(BadgeField field, Attendee attendee, String? eventName) {
    String content = field.content ?? '';
    
    print('🔍 FIELD CONTENT: Field "${field.id}" (${field.type})');
    print('🔍 FIELD CONTENT: Original content: "$content"');
    print('🔍 FIELD CONTENT: Attendee data: ${attendee.firstName} ${attendee.lastName} (${attendee.email})');
    print('🔍 FIELD CONTENT: Event name: $eventName');
    
    // Replace placeholders with actual data
    // Support both single {firstName} and double {{firstName}} curly braces
    final originalContent = content;
    
    // Single brace placeholders
    content = content.replaceAll('{firstName}', attendee.firstName);
    content = content.replaceAll('{lastName}', attendee.lastName);
    content = content.replaceAll('{fullName}', attendee.fullName);
    content = content.replaceAll('{email}', attendee.email);
    content = content.replaceAll('{ticketType}', attendee.ticketType);
    content = content.replaceAll('{eventName}', eventName ?? 'Event');
    content = content.replaceAll('{isVip}', attendee.isVip ? 'VIP' : '');
    content = content.replaceAll('{isCheckedIn}', attendee.isCheckedIn ? 'Checked In' : 'Not Checked In');
    
    // Double brace placeholders
    content = content.replaceAll('{{firstName}}', attendee.firstName);
    content = content.replaceAll('{{lastName}}', attendee.lastName);
    content = content.replaceAll('{{fullName}}', attendee.fullName);
    content = content.replaceAll('{{email}}', attendee.email);
    content = content.replaceAll('{{ticketType}}', attendee.ticketType);
    content = content.replaceAll('{{eventName}}', eventName ?? 'Event');
    content = content.replaceAll('{{isVip}}', attendee.isVip ? 'VIP' : '');
    content = content.replaceAll('{{isCheckedIn}}', attendee.isCheckedIn ? 'Checked In' : 'Not Checked In');
    
    // Additional placeholders that might be used (if they exist in the data)
    // Note: company, title, phone fields are not currently in the Attendee model
    // but we keep these placeholders for future compatibility
    
    // Handle newline characters properly
    content = content.replaceAll('\\n', '\n');
    content = content.replaceAll('\\r\\n', '\n');
    content = content.replaceAll('\\r', '\n');
    
    print('🔍 FIELD CONTENT: After substitution: "$content"');
    print('🔍 FIELD CONTENT: Content changed: ${originalContent != content}');
    
    // Debug: Check if any placeholders remain unresolved
    final remainingPlaceholders = RegExp(r'\{[^}]+\}').allMatches(content).toList();
    if (remainingPlaceholders.isNotEmpty) {
      print('⚠️ FIELD CONTENT: Unresolved placeholders found: ${remainingPlaceholders.map((m) => m.group(0)).join(", ")}');
    }
    
    return content;
  }

  /// Parse color string to PdfColor
  static PdfColor _parseColor(String colorString) {
    print('🔍 COLOR DEBUG: Attempting to parse color: "$colorString"');
    try {
      if (colorString.startsWith('#')) {
        final hex = colorString.substring(1);
        if (hex.length == 6) {
          // Add full opacity (255) for 6-digit hex colors
          print('🔍 COLOR DEBUG: 6-digit hex detected. Adding FF prefix. Original hex: "$hex", New hex: "FF$hex"');
          final color = int.parse('FF$hex', radix: 16);
          final resultColor = PdfColor.fromInt(color);
          print('🔍 COLOR DEBUG: Parsed integer value: ${color.toRadixString(16)}');
          print('🔍 COLOR DEBUG: Returning PdfColor: $resultColor');
          return resultColor;
        } else if (hex.length == 8) {
          // Use the alpha channel as provided
          print('🔍 COLOR DEBUG: 8-digit hex detected. Original hex: "$hex"');
          final color = int.parse(hex, radix: 16);
          final resultColor = PdfColor.fromInt(color);
          print('🔍 COLOR DEBUG: Parsed integer value: ${color.toRadixString(16)}');
          print('🔍 COLOR DEBUG: Returning PdfColor: $resultColor');
          return resultColor;
        }
      }
      // Default to black if parsing fails or format is unexpected
      print('⚠️ COLOR PARSING: Failed to parse color string "$colorString", defaulting to black.');
      return PdfColors.black;
    } catch (e) {
      print('❌ COLOR PARSING ERROR: Failed to parse color string "$colorString": $e, defaulting to black.');
      return PdfColors.black;
    }
  }

  /// Parse font weight string to pw.FontWeight
  static pw.FontWeight _parseFontWeight(String fontWeight) {
    switch (fontWeight.toLowerCase()) {
      case 'bold':
        return pw.FontWeight.bold;
      case 'normal':
      default:
        return pw.FontWeight.normal;
    }
  }

  /// Parse text align string to pw.TextAlign
  static pw.TextAlign _parseTextAlign(String textAlign) {
    switch (textAlign.toLowerCase()) {
      case 'left':
        return pw.TextAlign.left;
      case 'right':
        return pw.TextAlign.right;
      case 'center':
      default:
        return pw.TextAlign.center; // Default to center alignment
    }
  }

  /// Parse text alignment to cross-axis alignment for Column widget
  static pw.CrossAxisAlignment _parseTextAlignToCrossAxis(String textAlign) {
    switch (textAlign.toLowerCase()) {
      case 'left':
        return pw.CrossAxisAlignment.start;
      case 'right':
        return pw.CrossAxisAlignment.end;
      case 'center':
      default:
        return pw.CrossAxisAlignment.center; // Default to center alignment
    }
  }

  /// Get available printers
  static Future<List<Printer>> getAvailablePrinters() async {
    try {
      return await Printing.listPrinters();
    } catch (e) {
      print('Error getting printers: $e');
      return [];
    }
  }

  /// Check if printing is available on the platform
  static Future<bool> isPrintingAvailable() async {
    return await Printing.info() != null;
  }
}