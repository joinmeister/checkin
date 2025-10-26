import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class FileService {
  /// Save PDF data to Downloads folder
  static Future<String?> savePdfToDownloads({
    required Uint8List pdfData,
    required String fileName,
  }) async {
    try {
      // For web platform, use browser download
      if (kIsWeb) {
        return await _savePdfToWebDownloads(pdfData, fileName);
      }

      // Check Android version for permission handling
      int? androidVersion;
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        androidVersion = androidInfo.version.sdkInt;
        print('📱 Android SDK version: $androidVersion');
      }
      
      // Request storage permission for mobile platforms
      print('📁 Checking storage permission...');
      
      // For Android 13+ (API 33+), storage permission works differently
      PermissionStatus permission;
      
      if (Platform.isAndroid && androidVersion != null && androidVersion >= 33) {
        // Android 13+ - storage permission is auto-granted for Downloads
        print('📁 Android 13+ detected - no permission request needed');
        permission = PermissionStatus.granted;
      } else if (Platform.isAndroid) {
        // Android 12 and below - need storage permission
        print('📁 Requesting storage permission for Android 12 and below...');
        permission = await Permission.storage.status;
        
        if (!permission.isGranted) {
          permission = await Permission.storage.request();
          print('📁 Storage permission status: $permission');
        }
        
        if (!permission.isGranted) {
          print('⚠️ Storage permission denied, trying documents directory as fallback');
          return await savePdfToDocuments(pdfData: pdfData, fileName: fileName);
        }
      } else {
        // iOS or other platforms
        permission = await Permission.storage.request();
        print('📁 Storage permission status: $permission');
        
        if (!permission.isGranted) {
          print('⚠️ Storage permission denied, trying documents directory as fallback');
          return await savePdfToDocuments(pdfData: pdfData, fileName: fileName);
        }
      }

      // Get Downloads directory
      Directory? downloadsDir;
      
      if (Platform.isAndroid) {
        // For Android, use multiple fallback paths
        final downloadPaths = [
          '/storage/emulated/0/Download',
          '/storage/emulated/0/Downloads',
          '/sdcard/Download',
          '/sdcard/Downloads',
        ];
        
        for (final path in downloadPaths) {
          final dir = Directory(path);
          if (await dir.exists()) {
            downloadsDir = dir;
            print('✅ Found Downloads directory: $path');
            break;
          }
        }
        
        // If no Downloads folder found, use app documents directory
        if (downloadsDir == null) {
          print('⚠️ No Downloads folder found, using app documents directory');
          downloadsDir = await getApplicationDocumentsDirectory();
        }
      } else if (Platform.isIOS) {
        // For iOS, use documents directory (Files app accessible)
        downloadsDir = await getApplicationDocumentsDirectory();
      } else {
        // Fallback for other platforms
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      // Ensure directory exists
      if (!await downloadsDir.exists()) {
        print('📁 Creating directory: ${downloadsDir.path}');
        await downloadsDir.create(recursive: true);
      }

      // Create file path
      final filePath = '${downloadsDir.path}/$fileName';
      final file = File(filePath);

      // Write PDF data to file
      await file.writeAsBytes(pdfData);
      print('✅ PDF saved successfully to: $filePath');
      print('📄 File size: ${pdfData.length} bytes');

      return filePath;
    } catch (e) {
      print('Error saving PDF to Downloads: $e');
      // Try fallback to documents directory
      try {
        return await savePdfToDocuments(pdfData: pdfData, fileName: fileName);
      } catch (fallbackError) {
        print('Fallback save also failed: $fallbackError');
        return null;
      }
    }
  }

  /// Save PDF to web downloads (browser download)
  static Future<String?> _savePdfToWebDownloads(Uint8List pdfData, String fileName) async {
    try {
      // For web, we'll use the browser's download functionality
      // This is handled by the printing package's layoutPdf method
      print('Web platform detected - using browser download for: $fileName');
      return 'web_download_$fileName'; // Return a placeholder path
    } catch (e) {
      print('Error saving PDF to web downloads: $e');
      return null;
    }
  }

  /// Save PDF to app documents directory (always accessible)
  static Future<String?> savePdfToDocuments({
    required Uint8List pdfData,
    required String fileName,
  }) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final filePath = '${documentsDir.path}/$fileName';
      final file = File(filePath);

      await file.writeAsBytes(pdfData);
      return filePath;
    } catch (e) {
      print('Error saving PDF to Documents: $e');
      return null;
    }
  }

  /// Get Downloads directory path
  static Future<String?> getDownloadsPath() async {
    try {
      Directory? downloadsDir;
      
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getApplicationDocumentsDirectory();
        }
      } else if (Platform.isIOS) {
        downloadsDir = await getApplicationDocumentsDirectory();
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      return downloadsDir?.path;
    } catch (e) {
      print('Error getting Downloads path: $e');
      return null;
    }
  }

  /// Check if file exists
  static Future<bool> fileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Get file size in bytes
  static Future<int?> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Delete file
  static Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  /// List PDF files in Downloads/Documents directory
  static Future<List<FileSystemEntity>> listPdfFiles() async {
    try {
      final downloadsPath = await getDownloadsPath();
      if (downloadsPath == null) return [];

      final directory = Directory(downloadsPath);
      if (!await directory.exists()) return [];

      final files = await directory.list().toList();
      return files.where((file) => 
        file.path.toLowerCase().endsWith('.pdf')
      ).toList();
    } catch (e) {
      print('Error listing PDF files: $e');
      return [];
    }
  }
}
