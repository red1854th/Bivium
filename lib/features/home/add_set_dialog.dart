import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../core/theme.dart';
import '../../models/flashcard.dart';
import '../../services/google_drive_service.dart';
import 'drive_sheets_list_page.dart';
import 'sheet_selection_dialog.dart';
import 'widgets/sheet_input_widget.dart';

class AddSetDialog extends StatefulWidget {
  final Function(FlashcardSet) onAdd;
  final List<String> allTitles;
  final GoogleDriveService? driveService;

  const AddSetDialog({
    super.key,
    required this.onAdd,
    required this.allTitles,
    this.driveService,
  });

  @override
  State<AddSetDialog> createState() => _AddSetDialogState();
}

class _AddSetDialogState extends State<AddSetDialog> {
  bool _showSheetInput = false;

  String _uniquifyTitle(String title, List<String> existing) {
    if (!existing.contains(title)) return title;
    int n = 1;
    String next = '$title ($n)';
    while (existing.contains(next)) {
      n++;
      next = '$title ($n)';
    }
    return next;
  }

  Future<void> _handleOpenSheetDialog(String sheetId, String sheetName) async {
    debugPrint(
      '_handleOpenSheetDialog called with sheetId: $sheetId, sheetName: $sheetName',
    );

    if (!mounted) return;

    Navigator.of(context).pop(); // Close the input dialog

    if (!mounted) return;

    debugPrint('Opening SheetSelectionDialog...');
    final set = await Navigator.of(context).push<FlashcardSet>(
      MaterialPageRoute(
        builder: (_) => SheetSelectionDialog(
          sheetId: sheetId,
          sheetName: sheetName,
          service: widget.driveService,
          onConfirm: (result) => Navigator.of(context).pop(result),
        ),
      ),
    );

    debugPrint('SheetSelectionDialog returned with set: $set');

    if (set != null && mounted) {
      debugPrint('Processing returned set...');
      set.title = _uniquifyTitle(set.title, widget.allTitles);
      widget.onAdd(set);

      if (mounted) {
        debugPrint('Closing AddSetDialog...');
        Navigator.of(context).pop(); // Close add_set_dialog
      }
    } else {
      debugPrint('Set is null or not mounted');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.cDarkSurface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 800),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: AppColors.cBrand600,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'add_new_set'.tr(),

                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.cSlate100 : AppColors.cSlate800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (!_showSheetInput) ...[
              Text(
                'add_set_desc'.tr(),

                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.cSlate400 : AppColors.cSlate600,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => setState(() => _showSheetInput = true),
                  icon: const Icon(Icons.link, size: 20),
                  label: Text('enter_sheet_url'.tr()),

                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.cBrand600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.driveService == null
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('sign_in_required'.tr())),
                          );
                        }
                      : () async {
                          final result = await DriveSheetsListPage.open(
                            context,
                            widget.driveService!,
                          );
                          if (!context.mounted || result == null) return;
                          final set = result.set;
                          set.title = _uniquifyTitle(
                            set.title,
                            widget.allTitles,
                          );
                          widget.onAdd(set);
                          Navigator.of(context).pop();
                        },
                  icon: const Icon(Icons.folder_open_outlined, size: 20),
                  label: Text('pick_from_drive'.tr()),

                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.cBrand600,
                    side: const BorderSide(color: AppColors.cBrand600),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: SingleChildScrollView(
                  child: SheetInputWidget(
                    onAdd: widget.onAdd,
                    allTitles: widget.allTitles,
                    onOpenSheetDialog: _handleOpenSheetDialog,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
