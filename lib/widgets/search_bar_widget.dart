import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final bool enabled;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  const SearchBarWidget({
    Key? key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onClear,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        enabled: enabled,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: AppTheme.secondaryText,
            fontSize: 16,
          ),
          prefixIcon: prefixIcon ?? Icon(
            Icons.search,
            color: AppTheme.secondaryText,
          ),
          suffixIcon: _buildSuffixIcon(),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppTheme.primaryBlue,
              width: 2,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        style: TextStyle(
          color: AppTheme.primaryText,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (suffixIcon != null) {
      return suffixIcon;
    }

    if (controller.text.isNotEmpty && onClear != null) {
      return IconButton(
        icon: Icon(
          Icons.clear,
          color: AppTheme.secondaryText,
        ),
        onPressed: onClear,
        tooltip: 'Clear search',
      );
    }

    return null;
  }
}