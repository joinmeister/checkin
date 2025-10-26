import 'package:flutter/material.dart';
import '../models/event.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const EventCard({
    Key? key,
    required this.event,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status and live indicator
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Venue and date info
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      event.venue,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 4),
              
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateRange(),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondaryColor,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Statistics row
              Row(
                children: [
                  _buildStatItem(
                    Icons.people,
                    'Total',
                    event.totalAttendees.toString(),
                  ),
                  const SizedBox(width: 16),
                  _buildStatItem(
                    Icons.check_circle,
                    'Checked In',
                    event.checkedInCount.toString(),
                    color: AppTheme.successColor,
                  ),
                  const SizedBox(width: 16),
                  _buildStatItem(
                    Icons.star,
                    'VIP',
                    event.vipCount.toString(),
                    color: AppTheme.warningColor,
                  ),
                  const Spacer(),
                  _buildCheckInPercentage(),
                ],
              ),
              
              // Description if available
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  event.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color backgroundColor;
    Color textColor;
    IconData? icon;

    switch (event.displayStatus) {
      case 'live':
        backgroundColor = AppTheme.successColor;
        textColor = Colors.white;
        icon = Icons.live_tv;
        break;
      case 'upcoming':
        backgroundColor = AppTheme.primaryColor;
        textColor = Colors.white;
        icon = Icons.schedule;
        break;
      case 'completed':
        backgroundColor = AppTheme.textSecondaryColor;
        textColor = Colors.white;
        icon = Icons.check;
        break;
      case 'draft':
        backgroundColor = AppTheme.warningColor;
        textColor = Colors.white;
        icon = Icons.edit;
        break;
      default:
        backgroundColor = AppTheme.backgroundColor;
        textColor = AppTheme.textColor;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: textColor,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            event.displayStatus.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, {Color? color}) {
    return Column(
      children: [
        Icon(
          icon,
          size: 16,
          color: color ?? AppTheme.textSecondaryColor,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color ?? AppTheme.textColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckInPercentage() {
    final percentage = event.checkInPercentage;
    final color = percentage >= 80 
        ? AppTheme.successColor 
        : percentage >= 50 
            ? AppTheme.warningColor 
            : AppTheme.errorColor;

    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1),
          ),
          child: Center(
            child: Text(
              '${percentage.toInt()}%',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Check-in',
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.textSecondaryColor,
          ),
        ),
      ],
    );
  }

  String _formatDateRange() {
    final startDate = event.startDate;
    final endDate = event.endDate;
    
    // Check if it's the same day
    if (startDate.year == endDate.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day) {
      return '${_formatDate(startDate)} • ${_formatTime(startDate)} - ${_formatTime(endDate)}';
    } else {
      return '${_formatDate(startDate)} - ${_formatDate(endDate)}';
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour == 0 ? 12 : time.hour > 12 ? time.hour - 12 : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    
    return '$hour:$minute $period';
  }
}