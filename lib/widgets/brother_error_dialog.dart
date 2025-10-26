import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/brother_error_handler.dart';

class BrotherErrorDialog extends StatelessWidget {
  final BrotherError error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final bool showTechnicalDetails;

  const BrotherErrorDialog({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
    this.showTechnicalDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _getErrorIcon(),
            color: _getErrorColor(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _getErrorTitle(),
              style: TextStyle(color: _getErrorColor()),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              BrotherErrorHandler().getUserFriendlyMessage(error),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            _buildRecoveryActions(context),
            if (showTechnicalDetails) ...[
              const SizedBox(height: 16),
              _buildTechnicalDetails(context),
            ],
          ],
        ),
      ),
      actions: [
        if (showTechnicalDetails)
          TextButton(
            onPressed: () => _copyErrorDetails(context),
            child: const Text('Copy Details'),
          ),
        TextButton(
          onPressed: () => _showTroubleshooting(context),
          child: const Text('Troubleshoot'),
        ),
        if (onRetry != null && error.isRecoverable)
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRetry!();
            },
            child: const Text('Retry'),
          ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onDismiss?.call();
          },
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildRecoveryActions(BuildContext context) {
    final actions = BrotherErrorHandler().getRecoveryActions(error);
    
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Fixes:',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...actions.take(3).map((action) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(child: Text(action)),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildTechnicalDetails(BuildContext context) {
    return ExpansionTile(
      title: const Text('Technical Details'),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Error Type', error.type.toString().split('.').last),
              _buildDetailRow('Error Code', error.code),
              _buildDetailRow('Timestamp', error.timestamp.toString()),
              if (error.technicalDetails != null)
                _buildDetailRow('Details', error.technicalDetails!),
              if (error.context.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Context:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...error.context.entries.map((entry) =>
                  _buildDetailRow(entry.key, entry.value.toString())),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getErrorIcon() {
    switch (error.type) {
      case BrotherErrorType.connection:
        return Icons.link_off;
      case BrotherErrorType.authentication:
        return Icons.security;
      case BrotherErrorType.printing:
        return Icons.print_disabled;
      case BrotherErrorType.hardware:
        return Icons.hardware;
      case BrotherErrorType.configuration:
        return Icons.settings;
      case BrotherErrorType.permission:
        return Icons.block;
      case BrotherErrorType.network:
        return Icons.wifi_off;
      default:
        return Icons.error;
    }
  }

  Color _getErrorColor() {
    if (error.isRecoverable) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String _getErrorTitle() {
    switch (error.type) {
      case BrotherErrorType.connection:
        return 'Connection Error';
      case BrotherErrorType.authentication:
        return 'Authentication Error';
      case BrotherErrorType.printing:
        return 'Printing Error';
      case BrotherErrorType.hardware:
        return 'Printer Hardware Issue';
      case BrotherErrorType.configuration:
        return 'Configuration Error';
      case BrotherErrorType.permission:
        return 'Permission Required';
      case BrotherErrorType.network:
        return 'Network Error';
      default:
        return 'Printer Error';
    }
  }

  void _showTroubleshooting(BuildContext context) {
    Navigator.of(context).pop();
    showDialog(
      context: context,
      builder: (context) => BrotherTroubleshootingDialog(error: error),
    );
  }

  void _copyErrorDetails(BuildContext context) {
    final details = '''
Error Type: ${error.type.toString().split('.').last}
Error Code: ${error.code}
Message: ${error.message}
Timestamp: ${error.timestamp}
Technical Details: ${error.technicalDetails ?? 'N/A'}
Context: ${error.context}
''';

    Clipboard.setData(ClipboardData(text: details));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Error details copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Show error dialog
  static Future<void> show(
    BuildContext context,
    BrotherError error, {
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
    bool showTechnicalDetails = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BrotherErrorDialog(
        error: error,
        onRetry: onRetry,
        onDismiss: onDismiss,
        showTechnicalDetails: showTechnicalDetails,
      ),
    );
  }
}

class BrotherTroubleshootingDialog extends StatelessWidget {
  final BrotherError error;

  const BrotherTroubleshootingDialog({
    super.key,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final steps = BrotherErrorHandler().getTroubleshootingSteps(error);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.help_outline, color: Colors.blue),
          SizedBox(width: 8),
          Text('Troubleshooting Guide'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Follow these steps to resolve the issue:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: steps.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            steps[index],
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Compact error notification for non-critical errors
class BrotherErrorNotification extends StatelessWidget {
  final BrotherError error;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const BrotherErrorNotification({
    super.key,
    required this.error,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      color: _getBackgroundColor(),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                _getErrorIcon(),
                color: _getIconColor(),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getErrorTitle(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getTextColor(),
                      ),
                    ),
                    Text(
                      BrotherErrorHandler().getUserFriendlyMessage(error),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getTextColor().withOpacity(0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: _getTextColor(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getErrorIcon() {
    switch (error.type) {
      case BrotherErrorType.connection:
        return Icons.link_off;
      case BrotherErrorType.hardware:
        return Icons.warning;
      case BrotherErrorType.permission:
        return Icons.block;
      default:
        return Icons.info;
    }
  }

  Color _getBackgroundColor() {
    if (error.isRecoverable) {
      return Colors.orange.shade50;
    } else {
      return Colors.red.shade50;
    }
  }

  Color _getIconColor() {
    if (error.isRecoverable) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  Color _getTextColor() {
    if (error.isRecoverable) {
      return Colors.orange.shade800;
    } else {
      return Colors.red.shade800;
    }
  }

  String _getErrorTitle() {
    switch (error.type) {
      case BrotherErrorType.connection:
        return 'Connection Issue';
      case BrotherErrorType.hardware:
        return 'Printer Issue';
      case BrotherErrorType.permission:
        return 'Permission Needed';
      default:
        return 'Printer Error';
    }
  }
}