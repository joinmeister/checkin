import 'package:flutter_test/flutter_test.dart';
import 'package:event_checkin_mobile/models/brother_printer.dart';
import 'package:event_checkin_mobile/services/brother_error_handler.dart';

void main() {
  group('Brother Printer Models', () {
    test('BrotherPrinter model creation and serialization', () {
      final printer = BrotherPrinter(
        id: 'test_printer_1',
        name: 'Brother QL-820NWB',
        model: 'QL-820NWB',
        connectionType: PrinterConnectionType.bluetooth,
        capabilities: PrinterCapabilities(
          supportedLabelSizes: [
            LabelSize(
              id: '62x29',
              name: 'Address Label',
              widthMm: 62,
              heightMm: 29,
              isRoll: true,
            ),
          ],
          maxResolutionDpi: 300,
          supportsColor: false,
          supportsCutting: true,
          maxPrintWidth: 62,
          supportedFormats: ['PNG', 'BMP'],
          supportsBluetooth: true,
          supportsWifi: true,
          supportsUsb: false,
        ),
        isMfiCertified: true,
        bluetoothAddress: '00:11:22:33:44:55',
        ipAddress: null,
        status: PrinterStatus.disconnected,
        lastSeen: DateTime.now(),
        connectionData: {'test': 'data'},
      );

      expect(printer.id, 'test_printer_1');
      expect(printer.displayName, 'Brother QL-820NWB');
      expect(printer.isConnected, false);
      expect(printer.isAvailable, true);

      // Test JSON serialization
      final json = printer.toJson();
      expect(json['id'], 'test_printer_1');
      expect(json['connectionType'], 'bluetooth');
      expect(json['isMfiCertified'], true);

      // Test JSON deserialization
      final printerFromJson = BrotherPrinter.fromJson(json);
      expect(printerFromJson.id, printer.id);
      expect(printerFromJson.name, printer.name);
      expect(printerFromJson.connectionType, printer.connectionType);
    });

    test('PrinterCapabilities model', () {
      final capabilities = PrinterCapabilities(
        supportedLabelSizes: [],
        maxResolutionDpi: 300,
        supportsColor: false,
        supportsCutting: true,
        maxPrintWidth: 62,
        supportedFormats: ['PNG'],
        supportsBluetooth: true,
        supportsWifi: false,
        supportsUsb: false,
      );

      expect(capabilities.maxResolutionDpi, 300);
      expect(capabilities.supportsColor, false);
      expect(capabilities.supportsBluetooth, true);

      // Test JSON serialization
      final json = capabilities.toJson();
      final capabilitiesFromJson = PrinterCapabilities.fromJson(json);
      expect(capabilitiesFromJson.maxResolutionDpi, capabilities.maxResolutionDpi);
    });

    test('LabelSize model', () {
      final labelSize = LabelSize(
        id: '62x29',
        name: 'Address Label',
        widthMm: 62,
        heightMm: 29,
        isRoll: true,
      );

      expect(labelSize.displaySize, '62mm x 29mm');

      // Test JSON serialization
      final json = labelSize.toJson();
      final labelSizeFromJson = LabelSize.fromJson(json);
      expect(labelSizeFromJson.widthMm, labelSize.widthMm);
      expect(labelSizeFromJson.heightMm, labelSize.heightMm);
    });
  });

  group('Brother Error Handler', () {
    late BrotherErrorHandler errorHandler;

    setUp(() {
      errorHandler = BrotherErrorHandler();
    });

    test('Error parsing and categorization', () {
      final error = errorHandler.parseError(
        'Connection failed to Brother printer',
        errorCode: 'CONNECTION_FAILED',
      );

      expect(error.type, BrotherErrorType.connection);
      expect(error.code, 'CONNECTION_FAILED');
      expect(error.isRecoverable, true);
    });

    test('User-friendly error messages', () {
      final error = BrotherError(
        type: BrotherErrorType.hardware,
        code: BrotherErrorCodes.outOfLabels,
        message: 'Printer out of labels',
      );

      final userMessage = errorHandler.getUserFriendlyMessage(error);
      expect(userMessage, contains('out of labels'));
      expect(userMessage, contains('replace'));
    });

    test('Troubleshooting steps generation', () {
      final error = BrotherError(
        type: BrotherErrorType.connection,
        code: BrotherErrorCodes.connectionFailed,
        message: 'Connection failed',
      );

      final steps = errorHandler.getTroubleshootingSteps(error);
      expect(steps.isNotEmpty, true);
      expect(steps.any((step) => step.toLowerCase().contains('power')), true);
    });

    test('Recovery actions', () {
      final error = BrotherError(
        type: BrotherErrorType.hardware,
        code: BrotherErrorCodes.coverOpen,
        message: 'Cover open',
      );

      final actions = errorHandler.getRecoveryActions(error);
      expect(actions.isNotEmpty, true);
      expect(actions.any((action) => action.toLowerCase().contains('cover')), true);
    });

    test('Error statistics', () {
      // Clear any existing errors first
      errorHandler.clearErrorHistory();
      
      // Parse a few errors
      errorHandler.parseError('Connection failed', errorCode: 'CONNECTION_FAILED');
      errorHandler.parseError('Out of labels', errorCode: 'OUT_OF_LABELS');
      errorHandler.parseError('Print failed', errorCode: 'PRINT_FAILED');

      final stats = errorHandler.getErrorStatistics();
      expect(stats['totalErrors'], 3);
      expect(stats['errorsByType']['connection'], 1);
      expect(stats['errorsByType']['hardware'], 1);
      expect(stats['errorsByType']['printing'], 1);
    });
  });

  group('Print Job Models', () {
    test('PrintJob creation', () {
      final badgeData = BadgeData(
        attendeeId: 'attendee_1',
        attendeeName: 'John Doe',
        attendeeEmail: 'john@example.com',
        qrCode: 'QR123',
        isVip: false,
        templateData: {},
      );

      final printSettings = PrintSettings(
        labelSize: LabelSize(
          id: '62x29',
          name: 'Address Label',
          widthMm: 62,
          heightMm: 29,
          isRoll: true,
        ),
        copies: 1,
        autoCut: true,
        quality: PrintQuality.normal,
      );

      final printJob = PrintJob(
        id: 'job_1',
        printerId: 'printer_1',
        badgeData: badgeData,
        settings: printSettings,
        createdAt: DateTime.now(),
        priority: JobPriority.normal,
      );

      expect(printJob.id, 'job_1');
      expect(printJob.canRetry, true);
      expect(printJob.priority, JobPriority.normal);
    });

    test('PrintResult creation', () {
      final successResult = PrintResult.success(
        printTime: const Duration(seconds: 5),
        labelCount: 1,
      );

      expect(successResult.success, true);
      expect(successResult.printTime.inSeconds, 5);

      final failureResult = PrintResult.failure(
        errorMessage: 'Print failed',
        errorCode: 'PRINT_ERROR',
      );

      expect(failureResult.success, false);
      expect(failureResult.errorMessage, 'Print failed');
    });
  });
}