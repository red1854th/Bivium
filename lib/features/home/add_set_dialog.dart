import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../core/theme.dart';
import '../../models/flashcard.dart';
import '../../services/google_drive_service.dart';
import 'drive_sheets_list_page.dart';
import 'widgets/local_file_import_widget.dart';

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
                    'add_project_desc'.tr(),

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
                'add_project_desc'.tr(),

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
                  label: Text('local_language_file'.tr()),

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
                  onPressed:
                      (widget.driveService == null ||
                          widget.driveService!.currentUser == null)
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
                  label: Text('sheet_from_drive'.tr()),

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
              if (widget.driveService != null)
                Expanded(
                  child: SingleChildScrollView(
                    child: LocalFileImportWidget(
                      service: widget.driveService!,
                      onAdd: (set) {
                        set.title = _uniquifyTitle(set.title, widget.allTitles);
                        widget.onAdd(set);
                        Navigator.of(context).pop();
                      },
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
