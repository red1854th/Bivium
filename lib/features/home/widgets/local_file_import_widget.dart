import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/theme.dart';
import '../../../models/flashcard.dart';
import '../../../services/google_drive_service.dart';

class LocalFileImportWidget extends StatefulWidget {
  final GoogleDriveService service;
  final Function(FlashcardSet) onAdd;

  const LocalFileImportWidget({
    super.key,
    required this.service,
    required this.onAdd,
  });

  @override
  State<LocalFileImportWidget> createState() => _LocalFileImportWidgetState();
}

class _LocalFileImportWidgetState extends State<LocalFileImportWidget> {
  String? _fileContent;
  String? _fileName;
  final TextEditingController _regexController = TextEditingController(
    text: r'"([^"]+)"\s*=\s*"([^"]+)"', // Default for .strings or similar
  );
  List<Map<String, String>> _extractedData = [];
  bool _isUploading = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _fileName = result.files.single.name;
        _fileContent = String.fromCharCodes(result.files.single.bytes!);
        _extract();
      });
    }
  }

  void _extract() {
    if (_fileContent == null || _regexController.text.isEmpty) return;

    try {
      final regExp = RegExp(_regexController.text, multiLine: true);
      final matches = regExp.allMatches(_fileContent!);

      final List<Map<String, String>> results = [];
      for (final match in matches) {
        // We assume:
        // Group 1: Key (optional if only 2 groups)
        // Group 2: Source
        // Group 3: Target (if exists)

        final Map<String, String> entry = {};
        if (match.groupCount >= 3) {
          entry['key'] = match.group(1) ?? '';
          entry['source'] = match.group(2) ?? '';
          entry['target'] = match.group(3) ?? '';
        } else if (match.groupCount == 2) {
          entry['key'] = match.group(1) ?? '';
          entry['source'] = match.group(2) ?? '';
          entry['target'] = '';
        } else if (match.groupCount == 1) {
          entry['key'] = '';
          entry['source'] = match.group(1) ?? '';
          entry['target'] = '';
        }
        results.add(entry);
      }

      setState(() {
        _extractedData = results;
      });
    } catch (e) {
      debugPrint('Regex error: $e');
    }
  }

  Future<void> _handleUpload() async {
    if (_extractedData.isEmpty || _fileName == null) return;

    setState(() => _isUploading = true);

    try {
      // 1. Create Spreadsheet
      final title = _fileName!.split('.').first;
      final spreadsheetId = await widget.service.createSpreadsheet(title);

      if (spreadsheetId != null) {
        // 2. Upload Data
        final headers = ['Key', 'Source', 'Target'];
        final data = _extractedData
            .map((e) => [e['key'] ?? '', e['source'] ?? '', e['target'] ?? ''])
            .toList();

        await widget.service.uploadInitialData(spreadsheetId, headers, data);

        // 3. Create FlashcardSet
        final newSet = FlashcardSet(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          description: 'Imported from $_fileName',
          sheetId: spreadsheetId,
          gid: 0,
          keyColIdx: 0,
          frontColIdx: 1,
          backColIdx: 2,
          lastSynced: DateTime.now(),
          lastAccessed: DateTime.now(),
          extractRegex: _regexController.text,
        );

        widget.onAdd(newSet);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_fileContent == null)
          Center(
            child: ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.file_upload),
              label: Text('pick_file'.tr()),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          )
        else ...[
          Text(
            '${'file_name'.tr()}: $_fileName',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _regexController,
            decoration: InputDecoration(
              labelText: 'extraction_regex'.tr(),
              hintText: r'"([^"]+)"\s*=\s*"([^"]+)"',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _extract,
              ),
            ),
            onChanged: (_) => _extract(),
          ),
          const SizedBox(height: 16),
          Text(
            '${'preview_results'.tr()} (${_extractedData.length})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(
                color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _extractedData.isEmpty
                ? Center(child: Text('no_matches_found'.tr()))
                : ListView.builder(
                    itemCount: _extractedData.length,
                    itemBuilder: (context, index) {
                      final item = _extractedData[index];
                      return ListTile(
                        dense: true,
                        title: Text(item['source'] ?? ''),
                        subtitle: Text(item['key'] ?? ''),
                        trailing: Text(item['target'] ?? ''),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isUploading ? null : _handleUpload,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.cBrand600,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isUploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('upload_and_create_project'.tr()),
            ),
          ),
        ],
      ],
    );
  }
}
