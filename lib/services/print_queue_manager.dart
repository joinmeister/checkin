import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/brother_printer.dart';
import '../models/attendee.dart';
import '../models/badge_template.dart';
import 'print_job_processor.dart';

/// Queue management strategy
enum QueueStrategy {
  fifo,        // First In, First Out
  priority,    // Priority-based
  batch,       // Batch similar jobs
  adaptive     // Adaptive based on conditions
}

/// Batch configuration
class BatchConfig {
  final int maxBatchSize;
  final Duration maxWaitTime;
  final bool groupByPriority;
  final bool groupBySettings;
  final bool enableSmartBatching;

  const BatchConfig({
    this.maxBatchSize = 10,
    this.maxWaitTime = const Duration(seconds: 30),
    this.groupByPriority = true,
    this.groupBySettings = true,
    this.enableSmartBatching = true,
  });
}

/// Queue statistics
class QueueStatistics {
  final int totalJobs;
  final int pendingJobs;
  final int processingJobs;
  final int completedJobs;
  final int failedJobs;
  final double averageWaitTime;
  final double averageProcessingTime;
  final double throughputPerMinute;
  final Map<JobPriority, int> jobsByPriority;

  QueueStatistics({
    required this.totalJobs,
    required this.pendingJobs,
    required this.processingJobs,
    required this.completedJobs,
    required this.failedJobs,
    required this.averageWaitTime,
    required this.averageProcessingTime,
    required this.throughputPerMinute,
    required this.jobsByPriority,
  });
}

/// Batch of print jobs
class PrintJobBatch {
  final String id;
  final List<PrintJob> jobs;
  final DateTime createdAt;
  final JobPriority priority;
  final PrintSettings settings;
  final Duration estimatedProcessingTime;

  PrintJobBatch({
    required this.id,
    required this.jobs,
    required this.createdAt,
    required this.priority,
    required this.settings,
    required this.estimatedProcessingTime,
  });

  int get jobCount => jobs.length;
  bool get isEmpty => jobs.isEmpty;
  bool get isNotEmpty => jobs.isNotEmpty;
}

/// Print queue manager with advanced batching and optimization
class PrintQueueManager {
  static final PrintQueueManager _instance = PrintQueueManager._internal();
  factory PrintQueueManager() => _instance;
  PrintQueueManager._internal();

  final PrintJobProcessor _jobProcessor = PrintJobProcessor();
  final Uuid _uuid = const Uuid();

  final Queue<PrintJob> _pendingJobs = Queue<PrintJob>();
  final Map<String, PrintJobBatch> _pendingBatches = {};
  final Map<String, PrintJobBatch> _processingBatches = {};
  final Map<String, PrintJobBatch> _completedBatches = {};

  final StreamController<QueueStatistics> _statsController = StreamController<QueueStatistics>.broadcast();
  final StreamController<PrintJobBatch> _batchController = StreamController<PrintJobBatch>.broadcast();

  QueueStrategy _strategy = QueueStrategy.adaptive;
  BatchConfig _batchConfig = const BatchConfig();
  Timer? _batchTimer;
  Timer? _statsTimer;
  Timer? _optimizationTimer;

  bool _isInitialized = false;
  bool _isProcessing = false;

  // Performance tracking
  final List<DateTime> _completionTimes = [];
  final Map<String, Duration> _jobWaitTimes = {};
  final Map<String, Duration> _jobProcessingTimes = {};

  /// Stream of queue statistics
  Stream<QueueStatistics> get statisticsStream => _statsController.stream;

  /// Stream of batch updates
  Stream<PrintJobBatch> get batchStream => _batchController.stream;

  /// Current queue strategy
  QueueStrategy get strategy => _strategy;

  /// Current batch configuration
  BatchConfig get batchConfig => _batchConfig;

  /// Initialize the queue manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('🔧 Initializing Print Queue Manager...');

      // Initialize job processor
      await _jobProcessor.initialize();

      // Listen to job processor events
      _jobProcessor.jobStream.listen(_handleJobUpdate);
      _jobProcessor.resultStream.listen(_handleJobResult);

      // Start batch processing
      _startBatchProcessing();

      // Start statistics monitoring
      _startStatisticsMonitoring();

      // Start queue optimization
      _startQueueOptimization();

      _isInitialized = true;
      debugPrint('✅ Print Queue Manager initialized');
    } catch (e) {
      debugPrint('❌ Print Queue Manager initialization failed: $e');
      rethrow;
    }
  }

  /// Configure queue strategy
  void setQueueStrategy(QueueStrategy strategy) {
    _strategy = strategy;
    debugPrint('📋 Queue strategy changed to: $strategy');
    _optimizeQueue();
  }

  /// Configure batch settings
  void setBatchConfig(BatchConfig config) {
    _batchConfig = config;
    debugPrint('📦 Batch config updated: max size ${config.maxBatchSize}, max wait ${config.maxWaitTime.inSeconds}s');
  }

  /// Add job to queue
  Future<String> addJob({
    required PrintJob job,
    bool enableBatching = true,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      debugPrint('📋 Adding job to queue: ${job.id} (priority: ${job.priority})');

      // Record job submission time for wait time tracking
      _jobWaitTimes[job.id] = Duration.zero;

      if (enableBatching && _shouldBatch(job)) {
        await _addToBatch(job);
      } else {
        await _addToDirectQueue(job);
      }

      _updateStatistics();
      return job.id;
    } catch (e) {
      debugPrint('❌ Failed to add job to queue: $e');
      rethrow;
    }
  }

  /// Add multiple jobs to queue
  Future<List<String>> addJobs({
    required List<PrintJob> jobs,
    bool enableBatching = true,
  }) async {
    final jobIds = <String>[];

    for (final job in jobs) {
      try {
        final jobId = await addJob(job: job, enableBatching: enableBatching);
        jobIds.add(jobId);
      } catch (e) {
        debugPrint('❌ Failed to add job ${job.id}: $e');
      }
    }

    debugPrint('📋 Added ${jobIds.length}/${jobs.length} jobs to queue');
    return jobIds;
  }

  /// Get queue status
  QueueStatistics getStatistics() {
    final totalJobs = _pendingJobs.length + 
                     _pendingBatches.values.fold(0, (sum, batch) => sum + batch.jobCount) +
                     _processingBatches.values.fold(0, (sum, batch) => sum + batch.jobCount) +
                     _completedBatches.values.fold(0, (sum, batch) => sum + batch.jobCount);

    final pendingJobs = _pendingJobs.length + 
                       _pendingBatches.values.fold(0, (sum, batch) => sum + batch.jobCount);

    final processingJobs = _processingBatches.values.fold(0, (sum, batch) => sum + batch.jobCount);

    final completedJobs = _completedBatches.values.fold(0, (sum, batch) => sum + batch.jobCount);

    final jobsByPriority = <JobPriority, int>{};
    for (final priority in JobPriority.values) {
      jobsByPriority[priority] = 0;
    }

    // Count jobs by priority
    for (final job in _pendingJobs) {
      jobsByPriority[job.priority] = (jobsByPriority[job.priority] ?? 0) + 1;
    }

    for (final batch in _pendingBatches.values) {
      jobsByPriority[batch.priority] = (jobsByPriority[batch.priority] ?? 0) + batch.jobCount;
    }

    return QueueStatistics(
      totalJobs: totalJobs.toInt(),
      pendingJobs: pendingJobs.toInt(),
      processingJobs: processingJobs.toInt(),
      completedJobs: completedJobs.toInt(),
      failedJobs: 0, // TODO: Track failed jobs
      averageWaitTime: _calculateAverageWaitTime(),
      averageProcessingTime: _calculateAverageProcessingTime(),
      throughputPerMinute: _calculateThroughput(),
      jobsByPriority: jobsByPriority,
    );
  }

  /// Cancel a job
  Future<bool> cancelJob(String jobId) async {
    try {
      // Remove from pending queue
      _pendingJobs.removeWhere((job) => job.id == jobId);

      // Remove from batches
      for (final batch in _pendingBatches.values.toList()) {
        batch.jobs.removeWhere((job) => job.id == jobId);
        if (batch.isEmpty) {
          _pendingBatches.remove(batch.id);
        }
      }

      // Try to cancel in job processor
      await _jobProcessor.cancelJob(jobId);

      debugPrint('🚫 Cancelled job: $jobId');
      _updateStatistics();
      return true;
    } catch (e) {
      debugPrint('❌ Failed to cancel job $jobId: $e');
      return false;
    }
  }

  /// Clear all pending jobs
  void clearPendingJobs() {
    final count = _pendingJobs.length + _pendingBatches.length;
    _pendingJobs.clear();
    _pendingBatches.clear();
    
    debugPrint('🗑️ Cleared $count pending jobs/batches');
    _updateStatistics();
  }

  /// Pause queue processing
  void pauseProcessing() {
    _isProcessing = false;
    _batchTimer?.cancel();
    debugPrint('⏸️ Queue processing paused');
  }

  /// Resume queue processing
  void resumeProcessing() {
    if (!_isProcessing) {
      _isProcessing = true;
      _startBatchProcessing();
      debugPrint('▶️ Queue processing resumed');
    }
  }

  /// Determine if job should be batched
  bool _shouldBatch(PrintJob job) {
    if (!_batchConfig.enableSmartBatching) {
      return false;
    }

    // Don't batch urgent jobs
    if (job.priority == JobPriority.urgent) {
      return false;
    }

    // Check if there are similar jobs to batch with
    return _findSimilarJobs(job).isNotEmpty || _pendingJobs.length > 3;
  }

  /// Add job to batch
  Future<void> _addToBatch(PrintJob job) async {
    // Find existing compatible batch
    PrintJobBatch? compatibleBatch;
    
    for (final batch in _pendingBatches.values) {
      if (_isCompatibleForBatching(job, batch)) {
        compatibleBatch = batch;
        break;
      }
    }

    if (compatibleBatch != null && compatibleBatch.jobCount < _batchConfig.maxBatchSize) {
      // Add to existing batch
      compatibleBatch.jobs.add(job);
      debugPrint('📦 Added job ${job.id} to existing batch ${compatibleBatch.id}');
    } else {
      // Create new batch
      final batch = PrintJobBatch(
        id: _uuid.v4(),
        jobs: [job],
        createdAt: DateTime.now(),
        priority: job.priority,
        settings: job.settings,
        estimatedProcessingTime: _estimateProcessingTime([job]),
      );

      _pendingBatches[batch.id] = batch;
      _batchController.add(batch);
      debugPrint('📦 Created new batch ${batch.id} with job ${job.id}');
    }
  }

  /// Add job directly to queue (no batching)
  Future<void> _addToDirectQueue(PrintJob job) async {
    _pendingJobs.add(job);
    
    // Submit directly to job processor
    await _jobProcessor.submitPrintJob(
      attendee: _createAttendeeFromBadgeData(job.badgeData),
      template: _createTemplateFromBadgeData(job.badgeData),
      eventName: job.badgeData.templateData['eventName'] as String?,
      priority: job.priority,
      settings: job.settings,
    );

    debugPrint('📋 Added job ${job.id} directly to processing queue');
  }

  /// Check if job is compatible for batching
  bool _isCompatibleForBatching(PrintJob job, PrintJobBatch batch) {
    // Check priority compatibility
    if (_batchConfig.groupByPriority && job.priority != batch.priority) {
      return false;
    }

    // Check settings compatibility
    if (_batchConfig.groupBySettings) {
      // Compare key settings
      if (job.settings.labelSize.id != batch.settings.labelSize.id ||
          job.settings.quality != batch.settings.quality ||
          job.settings.autoCut != batch.settings.autoCut) {
        return false;
      }
    }

    return true;
  }

  /// Find similar jobs for batching
  List<PrintJob> _findSimilarJobs(PrintJob job) {
    return _pendingJobs.where((otherJob) {
      return job.priority == otherJob.priority &&
             job.settings.labelSize.id == otherJob.settings.labelSize.id;
    }).toList();
  }

  /// Start batch processing
  void _startBatchProcessing() {
    if (!_isProcessing) return;

    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _processPendingBatches();
    });
  }

  /// Process pending batches
  Future<void> _processPendingBatches() async {
    if (_pendingBatches.isEmpty) return;

    final now = DateTime.now();
    final batchesToProcess = <PrintJobBatch>[];

    // Find batches ready for processing
    for (final batch in _pendingBatches.values) {
      final waitTime = now.difference(batch.createdAt);
      
      if (batch.jobCount >= _batchConfig.maxBatchSize || 
          waitTime >= _batchConfig.maxWaitTime) {
        batchesToProcess.add(batch);
      }
    }

    // Process ready batches
    for (final batch in batchesToProcess) {
      await _processBatch(batch);
    }
  }

  /// Process a batch of jobs
  Future<void> _processBatch(PrintJobBatch batch) async {
    try {
      debugPrint('📦 Processing batch ${batch.id} with ${batch.jobCount} jobs');

      // Move to processing
      _pendingBatches.remove(batch.id);
      _processingBatches[batch.id] = batch;

      // Submit jobs to processor
      for (final job in batch.jobs) {
        await _jobProcessor.submitPrintJob(
          attendee: _createAttendeeFromBadgeData(job.badgeData),
          template: _createTemplateFromBadgeData(job.badgeData),
          eventName: job.badgeData.templateData['eventName'] as String?,
          priority: job.priority,
          settings: job.settings,
        );
      }

      debugPrint('📦 Submitted batch ${batch.id} for processing');
    } catch (e) {
      debugPrint('❌ Failed to process batch ${batch.id}: $e');
      
      // Move back to pending on error
      _processingBatches.remove(batch.id);
      _pendingBatches[batch.id] = batch;
    }
  }

  /// Handle job updates from processor
  void _handleJobUpdate(PrintJob job) {
    // Update wait times
    final waitTime = DateTime.now().difference(job.createdAt);
    _jobWaitTimes[job.id] = waitTime;
  }

  /// Handle job results from processor
  void _handleJobResult(PrintResult result) {
    final jobId = result.additionalData['jobId'] as String?;
    if (jobId != null) {
      // Record completion time
      _completionTimes.add(DateTime.now());
      
      // Keep only recent completion times
      final cutoff = DateTime.now().subtract(const Duration(hours: 1));
      _completionTimes.removeWhere((time) => time.isBefore(cutoff));

      // Record processing time
      _jobProcessingTimes[jobId] = result.printTime;

      // Move batch to completed if all jobs are done
      _checkBatchCompletion(jobId);
    }
  }

  /// Check if batch is completed
  void _checkBatchCompletion(String jobId) {
    for (final entry in _processingBatches.entries) {
      final batch = entry.value;
      final allJobsCompleted = batch.jobs.every((job) => 
        _jobProcessingTimes.containsKey(job.id));

      if (allJobsCompleted) {
        _processingBatches.remove(entry.key);
        _completedBatches[entry.key] = batch;
        
        debugPrint('✅ Batch ${batch.id} completed');
        break;
      }
    }
  }

  /// Start statistics monitoring
  void _startStatisticsMonitoring() {
    _statsTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _updateStatistics();
    });
  }

  /// Update and broadcast statistics
  void _updateStatistics() {
    final stats = getStatistics();
    _statsController.add(stats);
  }

  /// Start queue optimization
  void _startQueueOptimization() {
    _optimizationTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _optimizeQueue();
    });
  }

  /// Optimize queue based on current conditions
  void _optimizeQueue() {
    if (_strategy != QueueStrategy.adaptive) return;

    final stats = getStatistics();
    
    // Adapt strategy based on queue conditions
    if (stats.pendingJobs > 20) {
      // High load - prioritize batching
      setBatchConfig(BatchConfig(
        maxBatchSize: min(_batchConfig.maxBatchSize + 2, 15),
        maxWaitTime: Duration(seconds: max(_batchConfig.maxWaitTime.inSeconds - 5, 10)),
        groupByPriority: true,
        groupBySettings: true,
        enableSmartBatching: true,
      ));
    } else if (stats.pendingJobs < 5) {
      // Low load - reduce batching for faster response
      setBatchConfig(BatchConfig(
        maxBatchSize: max(_batchConfig.maxBatchSize - 1, 3),
        maxWaitTime: Duration(seconds: min(_batchConfig.maxWaitTime.inSeconds + 5, 60)),
        groupByPriority: false,
        groupBySettings: false,
        enableSmartBatching: false,
      ));
    }
  }

  /// Calculate average wait time
  double _calculateAverageWaitTime() {
    if (_jobWaitTimes.isEmpty) return 0.0;
    
    final totalWaitTime = _jobWaitTimes.values
        .map((duration) => duration.inMilliseconds)
        .reduce((a, b) => a + b);
    
    return totalWaitTime / _jobWaitTimes.length;
  }

  /// Calculate average processing time
  double _calculateAverageProcessingTime() {
    if (_jobProcessingTimes.isEmpty) return 0.0;
    
    final totalProcessingTime = _jobProcessingTimes.values
        .map((duration) => duration.inMilliseconds)
        .reduce((a, b) => a + b);
    
    return totalProcessingTime / _jobProcessingTimes.length;
  }

  /// Calculate throughput (jobs per minute)
  double _calculateThroughput() {
    if (_completionTimes.length < 2) return 0.0;
    
    final timeSpan = _completionTimes.last.difference(_completionTimes.first);
    if (timeSpan.inMinutes == 0) return 0.0;
    
    return _completionTimes.length / timeSpan.inMinutes;
  }

  /// Estimate processing time for jobs
  Duration _estimateProcessingTime(List<PrintJob> jobs) {
    // Base time per job (estimated)
    const baseTimePerJob = Duration(seconds: 15);
    return Duration(milliseconds: baseTimePerJob.inMilliseconds * jobs.length);
  }

  /// Create attendee from badge data (helper method)
  Attendee _createAttendeeFromBadgeData(BadgeData badgeData) {
    return Attendee(
      id: badgeData.attendeeId,
      eventId: '', // Will be filled from template data
      firstName: badgeData.attendeeName.split(' ').first,
      lastName: badgeData.attendeeName.split(' ').skip(1).join(' '),
      email: badgeData.attendeeEmail,
      ticketType: 'Standard',
      isVip: badgeData.isVip,
      isCheckedIn: true,
      qrCode: badgeData.qrCode,
      badgeGenerated: false,
      vipLogoUrl: badgeData.vipLogoUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Create template from badge data (helper method)
  BadgeTemplate _createTemplateFromBadgeData(BadgeData badgeData) {
    final templateData = badgeData.templateData['template'] as Map<String, dynamic>;
    return BadgeTemplate.fromJson(templateData);
  }

  /// Dispose resources
  void dispose() {
    _batchTimer?.cancel();
    _statsTimer?.cancel();
    _optimizationTimer?.cancel();
    _statsController.close();
    _batchController.close();
    _pendingJobs.clear();
    _pendingBatches.clear();
    _processingBatches.clear();
    _completedBatches.clear();
  }
}