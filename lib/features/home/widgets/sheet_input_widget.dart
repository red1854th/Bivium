import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../models/flashcard.dart';
import '../../../services/google_drive_service.dart';

class SheetInputWidget extends StatefulWidget {
  final Function(FlashcardSet) onAdd;
  final List<String> allTitles;
  final GoogleDriveService? driveService;
  final Function(String sheetId, String sheetName)? onOpenSheetDialog;

  const SheetInputWidget({
    super.key,
    required this.onAdd,
    required this.allTitles,
    this.driveService,
    this.onOpenSheetDialog,
  });

  @override
  State<SheetInputWidget> createState() => _SheetInputWidgetState();
}

class _SheetInputWidgetState extends State<SheetInputWidget> {
  final TextEditingController _idController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _idController.dispose();
    super.dispose();
  }

  void _onChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      final extractedId = extractSheetId(val);
      if (extractedId.length > 20) {
        _openSelectionDialog(extractedId);
      }
    });
  }

  Future<void> _openSelectionDialog(String sheetId) async {
    if (!mounted) return;

    // Use "New Project" as default title for link input
    String sheetName = "New Project";
    debugPrint('Opening selection dialog with sheetName: "$sheetName"');

    // Use callback instead of navigation
    widget.onOpenSheetDialog?.call(sheetId, sheetName);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Google Sheets URL or ID',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.cSlate100 : AppColors.cSlate800,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _idController,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'https://docs.google.com/spreadsheets/d/...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Enter a Google Sheets URL to open the configuration screen.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.cSlate400 : AppColors.cSlate600,
          ),
        ),
      ],
    );
  }
}
