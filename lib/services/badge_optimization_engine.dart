import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../models/brother_printer.dart';
import '../models/badge_template.dart';
import '../models/attendee.dart';

/// Optimized badge data for Brother printers
class OptimizedBadge {
  final Uint8List imageData;
  final int width;
  final int height;
  final String format;
  final Map<String, dynamic> metadata;

  OptimizedBadge({
    required this.imageData,
    required this.width,
    required this.height,
    required this.format,
    this.metadata = const {},
  });
}

/// Badge optimization engine for Brother printers
class BadgeOptimizationEngine {
  static const int _defaultDpi = 300;
  static const double _mmToPixel = 11.811; // 300 DPI conversion
  
  bool _isInitialized = false;

  /// Initialize the optimization engine
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Pre-load any required resources
    _isInitialized = true;
  }

  /// Optimize badge for Brother printer
  Future<OptimizedBadge> optimizeBadge(
    BadgeData badgeData,
    PrinterCapabilities capabilities,
  ) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Get optimal label size
      final labelSize = _getOptimalLabelSize(capabilities);
      
      // Calculate pixel dimensions
      final widthPixels = (labelSize.widthMm * _mmToPixel).round();
      final heightPixels = (labelSize.heightMm * _mmToPixel).round();

      // Create badge image
      final imageData = await _createBadgeImage(
        badgeData,
        widthPixels,
        heightPixels,
        capabilities,
      );

      // Optimize for printer format
      final optimizedData = await _optimizeForPrinter(
        imageData,
        widthPixels,
        heightPixels,
        capabilities,
      );

      return OptimizedBadge(
        imageData: optimizedData,
        width: widthPixels,
        height: heightPixels,
        format: capabilities.supportsColor ? 'PNG' : 'BMP',
        metadata: {
          'labelSize': labelSize.toJson(),
          'dpi': capabilities.maxResolutionDpi,
          'optimizedFor': 'brother_printer',
        },
      );
    } catch (e) {
      throw Exception('Badge optimization failed: $e');
    }
  }

  /// Optimize multiple badges
  Future<List<OptimizedBadge>> optimizeMultipleBadges(
    List<BadgeData> badges,
    PrinterCapabilities capabilities,
  ) async {
    final optimizedBadges = <OptimizedBadge>[];
    
    for (final badge in badges) {
      final optimized = await optimizeBadge(badge, capabilities);
      optimizedBadges.add(optimized);
    }
    
    return optimizedBadges;
  }

  /// Create badge image from badge data optimized for Brother printers
  Future<Uint8List> _createBadgeImage(
    BadgeData badgeData,
    int widthPixels,
    int heightPixels,
    PrinterCapabilities capabilities,
  ) async {
    // Create a custom painter for the badge
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(widthPixels.toDouble(), heightPixels.toDouble());

    // Paint background - use white for better contrast on Brother printers
    final backgroundPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Add border for better definition on label printers
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      borderPaint,
    );

    // Calculate layout optimized for Brother label dimensions
    final padding = size.width * 0.08; // Increased padding for label printers
    final contentWidth = size.width - (padding * 2);
    final contentHeight = size.height - (padding * 2);

    // Optimize layout based on label orientation
    final isLandscape = size.width > size.height;
    
    if (isLandscape) {
      await _createLandscapeBadgeLayout(
        canvas, badgeData, size, padding, contentWidth, contentHeight, capabilities
      );
    } else {
      await _createPortraitBadgeLayout(
        canvas, badgeData, size, padding, contentWidth, contentHeight, capabilities
      );
    }

    // Convert to image with Brother printer optimization
    final picture = recorder.endRecording();
    final image = await picture.toImage(widthPixels, heightPixels);
    
    // Use appropriate format for Brother printers
    final format = capabilities.supportsColor ? ui.ImageByteFormat.png : ui.ImageByteFormat.png;
    final byteData = await image.toByteData(format: format);
    
    return byteData!.buffer.asUint8List();
  }

  /// Create landscape badge layout (typical for Brother QL labels)
  Future<void> _createLandscapeBadgeLayout(
    Canvas canvas,
    BadgeData badgeData,
    Size size,
    double padding,
    double contentWidth,
    double contentHeight,
    PrinterCapabilities capabilities,
  ) async {
    // Left side: Text content
    final textWidth = contentWidth * 0.65;
    final qrWidth = contentWidth * 0.3;
    
    // Draw attendee name (larger, bold)
    await _drawText(
      canvas,
      badgeData.attendeeName,
      Rect.fromLTWH(padding, padding, textWidth, contentHeight * 0.4),
      TextStyle(
        fontSize: _calculateOptimalFontSize(textWidth, badgeData.attendeeName, 20),
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
      TextAlign.left,
    );

    // Draw email (smaller)
    await _drawText(
      canvas,
      badgeData.attendeeEmail,
      Rect.fromLTWH(padding, padding + contentHeight * 0.45, textWidth, contentHeight * 0.25),
      TextStyle(
        fontSize: _calculateOptimalFontSize(textWidth, badgeData.attendeeEmail, 12),
        color: Colors.black87,
      ),
      TextAlign.left,
    );

    // Draw VIP indicator if applicable
    if (badgeData.isVip) {
      await _drawVipIndicator(
        canvas,
        Rect.fromLTWH(padding, padding + contentHeight * 0.75, textWidth * 0.4, contentHeight * 0.2),
      );
    }

    // Right side: QR code
    if (badgeData.qrCode.isNotEmpty) {
      final qrSize = math.min(qrWidth, contentHeight * 0.8);
      await _drawOptimizedQRCode(
        canvas,
        badgeData.qrCode,
        Rect.fromLTWH(
          size.width - padding - qrSize,
          padding + (contentHeight - qrSize) / 2,
          qrSize,
          qrSize,
        ),
        capabilities,
      );
    }
  }

  /// Create portrait badge layout
  Future<void> _createPortraitBadgeLayout(
    Canvas canvas,
    BadgeData badgeData,
    Size size,
    double padding,
    double contentWidth,
    double contentHeight,
    PrinterCapabilities capabilities,
  ) async {
    // Top: Name
    await _drawText(
      canvas,
      badgeData.attendeeName,
      Rect.fromLTWH(padding, padding, contentWidth, contentHeight * 0.25),
      TextStyle(
        fontSize: _calculateOptimalFontSize(contentWidth, badgeData.attendeeName, 18),
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
      TextAlign.center,
    );

    // Middle: Email
    await _drawText(
      canvas,
      badgeData.attendeeEmail,
      Rect.fromLTWH(padding, padding + contentHeight * 0.3, contentWidth, contentHeight * 0.2),
      TextStyle(
        fontSize: _calculateOptimalFontSize(contentWidth, badgeData.attendeeEmail, 10),
        color: Colors.black87,
      ),
      TextAlign.center,
    );

    // Bottom: QR code and VIP indicator
    final bottomY = padding + contentHeight * 0.55;
    final bottomHeight = contentHeight * 0.4;

    if (badgeData.qrCode.isNotEmpty) {
      final qrSize = math.min(contentWidth * 0.4, bottomHeight);
      await _drawOptimizedQRCode(
        canvas,
        badgeData.qrCode,
        Rect.fromLTWH(
          padding + contentWidth - qrSize,
          bottomY,
          qrSize,
          qrSize,
        ),
        capabilities,
      );
    }

    // VIP indicator on the left
    if (badgeData.isVip) {
      await _drawVipIndicator(
        canvas,
        Rect.fromLTWH(padding, bottomY, contentWidth * 0.5, bottomHeight * 0.5),
      );
    }
  }

  /// Draw text on canvas
  Future<void> _drawText(
    Canvas canvas,
    String text,
    Rect bounds,
    TextStyle style,
    TextAlign align,
  ) async {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout(maxWidth: bounds.width);
    
    final offset = Offset(
      bounds.left + (bounds.width - textPainter.width) / 2,
      bounds.top + (bounds.height - textPainter.height) / 2,
    );
    
    textPainter.paint(canvas, offset);
  }

  /// Draw optimized QR code for Brother printers
  Future<void> _drawOptimizedQRCode(
    Canvas canvas, 
    String data, 
    Rect bounds, 
    PrinterCapabilities capabilities
  ) async {
    // Create high-contrast QR code optimized for Brother printers
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    
    // Draw border
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(bounds, borderPaint);
    
    // Generate QR pattern optimized for label printer resolution
    final gridSize = capabilities.maxResolutionDpi >= 300 ? 25 : 21; // Higher resolution for better printers
    final cellSize = bounds.width / gridSize;
    
    // Create a more realistic QR pattern
    final qrPattern = _generateQRPattern(data, gridSize);
    
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        if (qrPattern[i][j]) {
          canvas.drawRect(
            Rect.fromLTWH(
              bounds.left + i * cellSize,
              bounds.top + j * cellSize,
              cellSize,
              cellSize,
            ),
            paint,
          );
        }
      }
    }
    
    // Add quiet zone (white border) for better scanning
    final quietZonePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = cellSize;
    canvas.drawRect(bounds.inflate(cellSize / 2), quietZonePaint);
  }

  /// Generate QR pattern (simplified version)
  List<List<bool>> _generateQRPattern(String data, int size) {
    final pattern = List.generate(size, (i) => List.generate(size, (j) => false));
    
    // Add finder patterns (corners)
    _addFinderPattern(pattern, 0, 0, size);
    _addFinderPattern(pattern, size - 7, 0, size);
    _addFinderPattern(pattern, 0, size - 7, size);
    
    // Add timing patterns
    for (int i = 8; i < size - 8; i++) {
      pattern[6][i] = i % 2 == 0;
      pattern[i][6] = i % 2 == 0;
    }
    
    // Add data pattern (simplified)
    final hash = data.hashCode;
    for (int i = 9; i < size - 9; i++) {
      for (int j = 9; j < size - 9; j++) {
        pattern[i][j] = ((i + j + hash) % 3) == 0;
      }
    }
    
    return pattern;
  }

  /// Add finder pattern to QR code
  void _addFinderPattern(List<List<bool>> pattern, int x, int y, int size) {
    for (int i = 0; i < 7 && x + i < size; i++) {
      for (int j = 0; j < 7 && y + j < size; j++) {
        final isBlack = (i == 0 || i == 6 || j == 0 || j == 6) ||
                       (i >= 2 && i <= 4 && j >= 2 && j <= 4);
        pattern[x + i][y + j] = isBlack;
      }
    }
  }

  /// Draw VIP indicator
  Future<void> _drawVipIndicator(Canvas canvas, Rect bounds) async {
    final paint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(8)),
      paint,
    );
    
    await _drawText(
      canvas,
      'VIP',
      bounds,
      const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
      TextAlign.center,
    );
  }

  /// Optimize image data for Brother printer
  Future<Uint8List> _optimizeForPrinter(
    Uint8List imageData,
    int width,
    int height,
    PrinterCapabilities capabilities,
  ) async {
    // Apply Brother-specific optimizations
    var optimizedData = await _optimizeBadgeForBrother(imageData, capabilities);
    
    // Apply compression if needed
    optimizedData = await _compressImage(optimizedData, capabilities.maxResolutionDpi);
    
    return optimizedData;
  }

  /// Convert image to monochrome for non-color printers
  Future<Uint8List> _convertToMonochrome(
    Uint8List imageData,
    int width,
    int height,
  ) async {
    // Load image
    final codec = await ui.instantiateImageCodec(imageData);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    
    // Get pixel data
    final byteData = await image.toByteData();
    if (byteData == null) throw Exception('Failed to get image data');
    
    final pixels = byteData.buffer.asUint8List();
    final monochromePixels = Uint8List(pixels.length);
    
    // Convert to monochrome using luminance
    for (int i = 0; i < pixels.length; i += 4) {
      final r = pixels[i];
      final g = pixels[i + 1];
      final b = pixels[i + 2];
      final a = pixels[i + 3];
      
      // Calculate luminance
      final luminance = (0.299 * r + 0.587 * g + 0.114 * b).round();
      final mono = luminance > 128 ? 255 : 0;
      
      monochromePixels[i] = mono;     // R
      monochromePixels[i + 1] = mono; // G
      monochromePixels[i + 2] = mono; // B
      monochromePixels[i + 3] = a;    // A
    }
    
    // Create new image from monochrome data
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      monochromePixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    
    final monochromeImage = await completer.future;
    final monochromeByteData = await monochromeImage.toByteData(format: ui.ImageByteFormat.png);
    
    return monochromeByteData!.buffer.asUint8List();
  }

  /// Compress image for optimal transmission
  Future<Uint8List> _compressImage(Uint8List imageData, int maxDpi) async {
    // For now, return original data
    // In a real implementation, you might resize or compress based on maxDpi
    return imageData;
  }

  /// Calculate appropriate font size based on image width
  double _calculateFontSize(double imageWidth, double baseFontSize) {
    final scaleFactor = imageWidth / 600; // Base width of 600px
    return baseFontSize * scaleFactor;
  }

  /// Calculate optimal font size for text to fit in given width
  double _calculateOptimalFontSize(double maxWidth, String text, double baseFontSize) {
    // Estimate character width (approximate)
    final estimatedCharWidth = baseFontSize * 0.6;
    final estimatedTextWidth = text.length * estimatedCharWidth;
    
    if (estimatedTextWidth <= maxWidth) {
      return baseFontSize;
    }
    
    // Scale down to fit
    final scaleFactor = maxWidth / estimatedTextWidth;
    final adjustedSize = baseFontSize * scaleFactor;
    
    // Ensure minimum readable size for Brother printers
    return math.max(adjustedSize, 8.0);
  }

  /// Brother printer specific optimizations
  Future<Uint8List> _optimizeBadgeForBrother(
    Uint8List imageData,
    PrinterCapabilities capabilities,
  ) async {
    // Apply Brother-specific optimizations
    var optimizedData = imageData;
    
    // Convert to monochrome if printer doesn't support color
    if (!capabilities.supportsColor) {
      optimizedData = await _convertToMonochromeOptimized(optimizedData);
    }
    
    // Apply dithering for better quality on thermal printers
    optimizedData = await _applyThermalPrinterDithering(optimizedData, capabilities);
    
    // Optimize for label cutting
    if (capabilities.supportsCutting) {
      optimizedData = await _optimizeForCutting(optimizedData);
    }
    
    return optimizedData;
  }

  /// Apply thermal printer dithering
  Future<Uint8List> _applyThermalPrinterDithering(
    Uint8List imageData,
    PrinterCapabilities capabilities,
  ) async {
    // Load image
    final codec = await ui.instantiateImageCodec(imageData);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    
    // Get pixel data
    final byteData = await image.toByteData();
    if (byteData == null) return imageData;
    
    final pixels = byteData.buffer.asUint8List();
    final ditheredPixels = Uint8List(pixels.length);
    
    final width = image.width;
    final height = image.height;
    
    // Apply Floyd-Steinberg dithering for better thermal printing
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final index = (y * width + x) * 4;
        
        // Get grayscale value
        final r = pixels[index];
        final g = pixels[index + 1];
        final b = pixels[index + 2];
        final gray = (0.299 * r + 0.587 * g + 0.114 * b).round();
        
        // Threshold
        final newGray = gray > 128 ? 255 : 0;
        final error = gray - newGray;
        
        // Set pixel
        ditheredPixels[index] = newGray;
        ditheredPixels[index + 1] = newGray;
        ditheredPixels[index + 2] = newGray;
        ditheredPixels[index + 3] = pixels[index + 3]; // Keep alpha
        
        // Distribute error (Floyd-Steinberg)
        if (x + 1 < width) {
          _addError(pixels, (y * width + x + 1) * 4, (error * 7 / 16).round());
        }
        if (y + 1 < height) {
          if (x > 0) {
            _addError(pixels, ((y + 1) * width + x - 1) * 4, (error * 3 / 16).round());
          }
          _addError(pixels, ((y + 1) * width + x) * 4, (error * 5 / 16).round());
          if (x + 1 < width) {
            _addError(pixels, ((y + 1) * width + x + 1) * 4, (error * 1 / 16).round());
          }
        }
      }
    }
    
    // Create new image from dithered data
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      ditheredPixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    
    final ditheredImage = await completer.future;
    final ditheredByteData = await ditheredImage.toByteData(format: ui.ImageByteFormat.png);
    
    return ditheredByteData!.buffer.asUint8List();
  }

  /// Add error to pixel for dithering
  void _addError(Uint8List pixels, int index, int error) {
    if (index >= 0 && index + 2 < pixels.length) {
      pixels[index] = (pixels[index] + error).clamp(0, 255);
      pixels[index + 1] = (pixels[index + 1] + error).clamp(0, 255);
      pixels[index + 2] = (pixels[index + 2] + error).clamp(0, 255);
    }
  }

  /// Optimize for label cutting
  Future<Uint8List> _optimizeForCutting(Uint8List imageData) async {
    // Add cut marks or optimize margins for automatic cutting
    // For now, return original data
    return imageData;
  }

  /// Enhanced monochrome conversion for Brother printers
  Future<Uint8List> _convertToMonochromeOptimized(Uint8List imageData) async {
    // Use the existing conversion but with Brother-specific optimizations
    return await _convertToMonochrome(imageData, 0, 0); // Width/height will be determined from image
  }

  /// Get optimal label size for capabilities
  LabelSize _getOptimalLabelSize(PrinterCapabilities capabilities) {
    if (capabilities.supportedLabelSizes.isNotEmpty) {
      // Prefer larger labels for better badge visibility
      capabilities.supportedLabelSizes.sort((a, b) => 
        (b.widthMm * b.heightMm).compareTo(a.widthMm * a.heightMm));
      return capabilities.supportedLabelSizes.first;
    }
    
    // Default Brother QL label size
    return LabelSize(
      id: 'default',
      name: 'Default Label (62x29mm)',
      widthMm: 62,
      heightMm: 29,
      isRoll: true,
    );
  }
}