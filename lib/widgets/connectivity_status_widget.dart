import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendee_provider.dart';
import '../services/connectivity_service.dart';
import '../utils/app_theme.dart';

class ConnectivityStatusWidget extends StatelessWidget {
  const ConnectivityStatusWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendeeProvider>(
      builder: (context, attendeeProvider, child) {
        final isOffline = attendeeProvider.isOffline;
        final queuedCount = attendeeProvider.queuedActionsCount;
        
        if (!isOffline && queuedCount == 0) {
          return const SizedBox.shrink(); // Hide when online and no queued actions
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isOffline ? AppTheme.errorColor : AppTheme.warningColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOffline ? Icons.cloud_off : Icons.sync,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isOffline 
                    ? 'Offline - $queuedCount actions queued'
                    : 'Online - $queuedCount actions pending sync',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ConnectivityStatusBanner extends StatelessWidget {
  const ConnectivityStatusBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AttendeeProvider>(
      builder: (context, attendeeProvider, child) {
        final isOffline = attendeeProvider.isOffline;
        final queuedCount = attendeeProvider.queuedActionsCount;
        
        if (!isOffline && queuedCount == 0) {
          return const SizedBox.shrink();
        }
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isOffline ? AppTheme.errorColor : AppTheme.warningColor,
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Icon(
                  isOffline ? Icons.cloud_off : Icons.sync,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isOffline ? 'Working Offline' : 'Syncing Data',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (queuedCount > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '$queuedCount ${queuedCount == 1 ? 'action' : 'actions'} ${isOffline ? 'queued for sync' : 'pending'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isOffline && queuedCount > 0)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}