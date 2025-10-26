import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendee_provider.dart';
import '../services/offline_queue_service.dart';
import '../services/sync_service.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

class OfflineQueueDialog extends StatefulWidget {
  const OfflineQueueDialog({Key? key}) : super(key: key);

  @override
  State<OfflineQueueDialog> createState() => _OfflineQueueDialogState();
}

class _OfflineQueueDialogState extends State<OfflineQueueDialog> {
  List<QueuedAction> _queuedActions = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadQueuedActions();
  }

  Future<void> _loadQueuedActions() async {
    try {
      final queueService = Provider.of<AttendeeProvider>(context, listen: false).queueService;
      final actions = queueService.queue;
      setState(() {
        _queuedActions = actions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _syncActions() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final syncService = Provider.of<SyncService>(context, listen: false);
      await syncService.sync();
      await _loadQueuedActions(); // Reload to see updated queue
      
      // Force refresh the attendee provider's queue count
      final attendeeProvider = Provider.of<AttendeeProvider>(context, listen: false);
      attendeeProvider.refreshQueueCount();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync completed successfully'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _removeAction(QueuedAction action) async {
    try {
      final queueService = Provider.of<AttendeeProvider>(context, listen: false).queueService;
      await queueService.removeFromQueue(action.id);
      await _loadQueuedActions();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Action removed from queue'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove action: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  String _getActionDescription(QueuedAction action) {
    switch (action.type) {
      case QueueActionType.checkInByQR:
        return 'QR Check-in: ${action.data['qrCode'] ?? 'Unknown'}';
      case QueueActionType.checkInById:
        return 'ID Check-in: ${action.data['attendeeId'] ?? 'Unknown'}';
      case QueueActionType.walkInRegistration:
        final firstName = action.data['firstName'] ?? '';
        final lastName = action.data['lastName'] ?? '';
        return 'Walk-in: $firstName $lastName';
      case QueueActionType.timingData:
        return 'Analytics: ${action.data['checkinType'] ?? 'Unknown'} timing';
    }
  }

  IconData _getActionIcon(QueuedAction action) {
    switch (action.type) {
      case QueueActionType.checkInByQR:
        return Icons.qr_code;
      case QueueActionType.checkInById:
        return Icons.person;
      case QueueActionType.walkInRegistration:
        return Icons.person_add;
      case QueueActionType.timingData:
        return Icons.analytics;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sync,
                  color: AppTheme.primaryBlue,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Offline Queue',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Queue summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.queue,
                    color: AppTheme.primaryBlue,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_queuedActions.length} actions in queue',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing || _queuedActions.isEmpty ? null : _syncActions,
                    icon: _isSyncing 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                    label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _loadQueuedActions,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Queue list
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _queuedActions.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: AppTheme.successGreen,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No actions in queue',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.secondaryText,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'All actions have been synced',
                            style: TextStyle(
                              color: AppTheme.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _queuedActions.length,
                      itemBuilder: (context, index) {
                        final action = _queuedActions[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                              child: Icon(
                                _getActionIcon(action),
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                            title: Text(_getActionDescription(action)),
                            subtitle: Text(
                              'Queued: ${_formatDateTime(action.timestamp)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: IconButton(
                              onPressed: () => _showRemoveConfirmation(action),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppTheme.errorRed,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showRemoveConfirmation(QueuedAction action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Action'),
        content: Text('Are you sure you want to remove this action from the queue?\n\n${_getActionDescription(action)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeAction(action);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.errorRed,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}