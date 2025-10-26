import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/brother_printer.dart';
import '../models/attendee.dart';
import '../models/badge_template.dart';
import 'brother_printer_service.dart';
import 'badge_optimization_engine.dart';

/// Print job status
enum PrintJobStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
  retrying
}

/// Print job processing engine
class PrintJobProcessor {
  static final PrintJobProcessor _instance = PrintJobProcessor._internal();
  factory PrintJobProcessor() => _instance;
  PrintJobProcessor._internal();

  final BrotherPrinterServiceImpl _printerService = BrotherPrinterServiceImpl();
  final BadgeOptimizationEngine _optimizationEngine = BadgeOptimizationEngine();
  final Uuid _uuid = const Uuid();

  final Queue<PrintJob> _jobQueue = Queue<PrintJob>();
  final Map<String, PrintJob> _activeJobs = {};
  final Map<String, PrintJob> _completedJobs = {};
  final Map<String, PrintResult> _jobResults = {};

  final StreamController<PrintJob> _jobController = StreamController<PrintJob>.broadcast();
  final StreamController<PrintResult> _resultController = StreamController<PrintResult>.broadcast();

  bool _isProcessing = false;
  Timer? _processingTimer;
  Timer? _cleanupTimer;

  // Configuration
  static const int _maxConcurrentJobs = 3;
  static const Duration _jobTimeout = Duration(minutes: 2);
  static const Duration _processingInterval = Duration(milliseconds: 500);
  static const Duration _cleanupInterval = Duration(minutes: 10);
  static const int _maxCompletedJobs = 100;

  /// Stream of job status updates
  Stream<PrintJob> get jobStream => _jobController.stream;

  /// Stream of print results
  Stream<PrintResult> get resultStream => _resultController.stream;

  /// Get current queue status
  Map<String, dynamic> get queueStatus => {
    'pending': _jobQueue.length,
    'active': _activeJobs.length,
    'completed': _completedJobs.length,
    'isProcessing': _isProcessing,
  };

  /// Initialize the print job processor
  Future<void> initialize() async {
    try {
      debugPrint('🔧 Initializing Print Job Processor...');

      // Initialize dependencies
      await _printerService.initialize();
      await _optimizationEngine.initialize();

      // Start processing loop
      _startProcessing();

      // Start cleanup timer
      _startCleanup();

      debugPrint('✅ Print Job Processor initialized');
    } catch (e) {
      debugPrint('❌ Print Job Processor initialization failed: $e');
      rethrow;
    }
  }

  /// Submit a print job
  Future<String> submitPrintJob({
    required Attendee attendee,
    required BadgeTemplate template,
    String? eventName,
    JobPriority priority = JobPriority.normal,
    PrintSettings? settings,
  }) async {
    try {
      // Create badge data
      final badgeData = BadgeData(
        attendeeId: attendee.id,
        attendeeName: attendee.fullName,
        attendeeEmail: attendee.email,
        qrCode: attendee.qrCode,
        vipLogoUrl: attendee.vipLogoUrl,
        isVip: attendee.isVip,
        templateData: {
          'template': template.toJson(),
          'eventName': eventName,
        },
      );

      // Get printer capabilities for settings
      final printer = _printerService.connectedPrinter;
      if (printer == null) {
        throw Exception('No printer connected');
      }

      // Create default settings if not provided
      final printSettings = settings ?? PrintSettings(
        labelSize: _getOptimalLabelSize(printer.capabilities),
        copies: 1,
        autoCut: true,
        quality: PrintQuality.normal,
      );

      // Create print job
      final job = PrintJob(
        id: _uuid.v4(),
        printerId: printer.id,
        badgeData: badgeData,
        settings: printSettings,
        createdAt: DateTime.now(),
        priority: priority,
      );

      // Add to queue
      _addJobToQueue(job);

      debugPrint('📋 Print job submitted: ${job.id} for ${attendee.fullName}');
      return job.id;
    } catch (e) {
      debugPrint('❌ Failed to submit print job: $e');
      rethrow;
    }
  }

  /// Submit multiple print jobs
  Future<List<String>> submitMultiplePrintJobs({
    required List<Attendee> attendees,
    required BadgeTemplate template,
    String? eventName,
    JobPriority priority = JobPriority.normal,
    PrintSettings? settings,
  }) async {
    final jobIds = <String>[];

    for (final attendee in attendees) {
      try {
        final jobId = await submitPrintJob(
          attendee: attendee,
          template: template,
          eventName: eventName,
          priority: priority,
          settings: settings,
        );
        jobIds.add(jobId);
      } catch (e) {
        debugPrint('❌ Failed to submit job for ${attendee.fullName}: $e');
        // Continue with other attendees
      }
    }

    debugPrint('📋 Submitted ${jobIds.length}/${attendees.length} print jobs');
    return jobIds;
  }

  /// Get job status
  PrintJob? getJob(String jobId) {
    return _activeJobs[jobId] ?? _completedJobs[jobId];
  }

  /// Get job result
  PrintResult? getJobResult(String jobId) {
    return _jobResults[jobId];
  }

  /// Cancel a job
  Future<bool> cancelJob(String jobId) async {
    try {
      // Remove from queue if pending
      _jobQueue.removeWhere((job) => job.id == jobId);

      // Cancel active job
      final activeJob = _activeJobs[jobId];
      if (activeJob != null) {
        final cancelledJob = activeJob.copyWith(
          // Add status field to PrintJob model if needed
        );
        
        _activeJobs.remove(jobId);
        _completedJobs[jobId] = cancelledJob;

        final result = PrintResult.failure(
          errorMessage: 'Job cancelled by user',
          errorCode: 'CANCELLED',
        );
        _jobResults[jobId] = result;

        _jobController.add(cancelledJob);
        _resultController.add(result);

        debugPrint('🚫 Cancelled job: $jobId');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Failed to cancel job $jobId: $e');
      return false;
    }
  }

  /// Retry a failed job
  Future<bool> retryJob(String jobId) async {
    try {
      final job = _completedJobs[jobId];
      if (job == null || job.canRetry) {
        return false;
      }

      // Create new job with incremented retry count
      final retryJob = job.copyWith(
        id: _uuid.v4(), // New ID for retry
        retryCount: job.retryCount + 1,
        createdAt: DateTime.now(),
      );

      // Add back to queue
      _addJobToQueue(retryJob);

      debugPrint('🔄 Retrying job: $jobId as ${retryJob.id}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to retry job $jobId: $e');
      return false;
    }
  }

  /// Clear completed jobs
  void clearCompletedJobs() {
    final count = _completedJobs.length;
    _completedJobs.clear();
    
    // Keep only recent results
    final recentResults = <String, PrintResult>{};
    final cutoffTime = DateTime.now().subtract(const Duration(hours: 1));
    
    for (final entry in _jobResults.entries) {
      if (entry.value.printTime.inMilliseconds > cutoffTime.millisecondsSinceEpoch) {
        recentResults[entry.key] = entry.value;
      }
    }
    
    _jobResults.clear();
    _jobResults.addAll(recentResults);

    debugPrint('🗑️ Cleared $count completed jobs');
  }

  /// Get queue statistics
  Map<String, dynamic> getQueueStatistics() {
    final now = DateTime.now();
    final recentJobs = _completedJobs.values.where(
      (job) => now.difference(job.createdAt).inHours < 24
    ).toList();

    final successfulJobs = recentJobs.where(
      (job) => _jobResults[job.id]?.success == true
    ).length;

    final failedJobs = recentJobs.where(
      (job) => _jobResults[job.id]?.success == false
    ).length;

    return {
      'totalProcessed': recentJobs.length,
      'successful': successfulJobs,
      'failed': failedJobs,
      'successRate': recentJobs.isNotEmpty ? (successfulJobs / recentJobs.length) * 100 : 0.0,
      'averageProcessingTime': _calculateAverageProcessingTime(recentJobs),
      'queueLength': _jobQueue.length,
      'activeJobs': _activeJobs.length,
    };
  }

  /// Add job to queue with priority ordering
  void _addJobToQueue(PrintJob job) {
    // Insert job based on priority
    bool inserted = false;
    final queueList = _jobQueue.toList();
    
    for (int i = 0; i < queueList.length; i++) {
      if (job.priority.index > queueList[i].priority.index) {
        _jobQueue.clear();
        _jobQueue.addAll(queueList.take(i));
        _jobQueue.add(job);
        _jobQueue.addAll(queueList.skip(i));
        inserted = true;
        break;
      }
    }
    
    if (!inserted) {
      _jobQueue.add(job);
    }

    _jobController.add(job);
    debugPrint('📋 Added job to queue: ${job.id} (priority: ${job.priority})');
  }

  /// Start the processing loop
  void _startProcessing() {
    if (_isProcessing) return;

    _isProcessing = true;
    _processingTimer = Timer.periodic(_processingInterval, (timer) {
      _processNextJobs();
    });

    debugPrint('▶️ Started print job processing');
  }

  /// Stop the processing loop
  void _stopProcessing() {
    _isProcessing = false;
    _processingTimer?.cancel();
    debugPrint('⏹️ Stopped print job processing');
  }

  /// Process next jobs in queue
  Future<void> _processNextJobs() async {
    if (_activeJobs.length >= _maxConcurrentJobs || _jobQueue.isEmpty) {
      return;
    }

    while (_activeJobs.length < _maxConcurrentJobs && _jobQueue.isNotEmpty) {
      final job = _jobQueue.removeFirst();
      _processJob(job);
    }
  }

  /// Process a single job
  Future<void> _processJob(PrintJob job) async {
    try {
      debugPrint('🔄 Processing job: ${job.id}');
      
      _activeJobs[job.id] = job;
      _jobController.add(job);

      // Set timeout for job
      Timer(_jobTimeout, () {
        if (_activeJobs.containsKey(job.id)) {
          _handleJobTimeout(job);
        }
      });

      final startTime = DateTime.now();

      // Process the job
      final result = await _executeJob(job);
      
      final processingTime = DateTime.now().difference(startTime);
      final finalResult = PrintResult(
        success: result.success,
        errorMessage: result.errorMessage,
        errorCode: result.errorCode,
        printTime: processingTime,
        labelCount: result.labelCount,
        additionalData: {
          ...result.additionalData,
          'processingTime': processingTime.inMilliseconds,
          'jobId': job.id,
        },
      );

      // Move job to completed
      _activeJobs.remove(job.id);
      _completedJobs[job.id] = job;
      _jobResults[job.id] = finalResult;

      _jobController.add(job);
      _resultController.add(finalResult);

      if (finalResult.success) {
        debugPrint('✅ Job completed: ${job.id} in ${processingTime.inMilliseconds}ms');
      } else {
        debugPrint('❌ Job failed: ${job.id} - ${finalResult.errorMessage}');
      }

    } catch (e) {
      debugPrint('❌ Job processing error: ${job.id} - $e');
      
      _activeJobs.remove(job.id);
      _completedJobs[job.id] = job;

      final errorResult = PrintResult.failure(
        errorMessage: 'Job processing error: $e',
        errorCode: 'PROCESSING_ERROR',
      );
      _jobResults[job.id] = errorResult;

      _jobController.add(job);
      _resultController.add(errorResult);
    }
  }

  /// Execute the actual print job
  Future<PrintResult> _executeJob(PrintJob job) async {
    try {
      // Optimize badge for printing
      final printer = _printerService.connectedPrinter;
      if (printer == null) {
        return PrintResult.failure(
          errorMessage: 'No printer connected',
          errorCode: 'NO_PRINTER',
        );
      }

      // Print the badge
      return await _printerService.printBadge(job.badgeData);
    } catch (e) {
      return PrintResult.failure(
        errorMessage: 'Print execution failed: $e',
        errorCode: 'EXECUTION_ERROR',
      );
    }
  }

  /// Handle job timeout
  void _handleJobTimeout(PrintJob job) {
    debugPrint('⏰ Job timeout: ${job.id}');
    
    _activeJobs.remove(job.id);
    _completedJobs[job.id] = job;

    final timeoutResult = PrintResult.failure(
      errorMessage: 'Job timeout after ${_jobTimeout.inSeconds} seconds',
      errorCode: 'TIMEOUT',
      printTime: _jobTimeout,
    );
    _jobResults[job.id] = timeoutResult;

    _jobController.add(job);
    _resultController.add(timeoutResult);
  }

  /// Start cleanup timer
  void _startCleanup() {
    _cleanupTimer = Timer.periodic(_cleanupInterval, (timer) {
      _performCleanup();
    });
  }

  /// Perform periodic cleanup
  void _performCleanup() {
    final now = DateTime.now();
    final cutoffTime = now.subtract(const Duration(hours: 24));

    // Remove old completed jobs
    final oldJobs = _completedJobs.entries
        .where((entry) => entry.value.createdAt.isBefore(cutoffTime))
        .map((entry) => entry.key)
        .toList();

    for (final jobId in oldJobs) {
      _completedJobs.remove(jobId);
      _jobResults.remove(jobId);
    }

    // Limit completed jobs size
    if (_completedJobs.length > _maxCompletedJobs) {
      final sortedJobs = _completedJobs.entries.toList()
        ..sort((a, b) => b.value.createdAt.compareTo(a.value.createdAt));

      final toRemove = sortedJobs.skip(_maxCompletedJobs).map((e) => e.key).toList();
      for (final jobId in toRemove) {
        _completedJobs.remove(jobId);
        _jobResults.remove(jobId);
      }
    }

    if (oldJobs.isNotEmpty) {
      debugPrint('🧹 Cleaned up ${oldJobs.length} old jobs');
    }
  }

  /// Get optimal label size for printer
  LabelSize _getOptimalLabelSize(PrinterCapabilities capabilities) {
    if (capabilities.supportedLabelSizes.isNotEmpty) {
      return capabilities.supportedLabelSizes.first;
    }
    
    return LabelSize(
      id: 'default',
      name: 'Default Label',
      widthMm: 62,
      heightMm: 29,
      isRoll: true,
    );
  }

  /// Calculate average processing time
  double _calculateAverageProcessingTime(List<PrintJob> jobs) {
    if (jobs.isEmpty) return 0.0;

    final processingTimes = jobs
        .map((job) => _jobResults[job.id]?.printTime.inMilliseconds ?? 0)
        .where((time) => time > 0)
        .toList();

    if (processingTimes.isEmpty) return 0.0;

    final sum = processingTimes.reduce((a, b) => a + b);
    return sum / processingTimes.length;
  }

  /// Dispose resources
  void dispose() {
    _stopProcessing();
    _cleanupTimer?.cancel();
    _jobController.close();
    _resultController.close();
    _jobQueue.clear();
    _activeJobs.clear();
    _completedJobs.clear();
    _jobResults.clear();
  }
}