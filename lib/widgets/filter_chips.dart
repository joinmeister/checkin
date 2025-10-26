import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class FilterChips extends StatelessWidget {
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final List<Map<String, String>> filters;
  final bool scrollable;

  const FilterChips({
    Key? key,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.filters,
    this.scrollable = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (scrollable) {
      return SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: filters.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final filter = filters[index];
            return _buildFilterChip(filter);
          },
        ),
      );
    } else {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: filters.map((filter) => _buildFilterChip(filter)).toList(),
      );
    }
  }

  Widget _buildFilterChip(Map<String, String> filter) {
    final value = filter['value']!;
    final label = filter['label']!;
    final isSelected = selectedFilter == value;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppTheme.textColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          onFilterChanged(value);
        }
      },
      backgroundColor: Colors.white,
      selectedColor: AppTheme.primaryColor,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}