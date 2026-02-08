import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/theme.dart';
import '../../models/flashcard.dart';
import '../../services/google_drive_service.dart';

/// Page shown after selecting a sheet: configure columns and title.
class SheetSelectionDialog extends StatefulWidget {
  final String sheetId;
  final String sheetName;
  final GoogleDriveService? service;
  final Function(FlashcardSet) onConfirm;

  const SheetSelectionDialog({
    super.key,
    required this.sheetId,
    required this.sheetName,
    this.service,
    required this.onConfirm,
  });


  @override
  State<SheetSelectionDialog> createState() => _SheetSelectionDialogState();
}

class _SheetSelectionDialogState extends State<SheetSelectionDialog> {
  late TextEditingController _titleController;
  List<String> _headers = [];
  bool _loadingHeaders = true;
  int? _keyColIdx;
  int _sourceColIdx = 0;
  int _targetColIdx = 1;
  int? _remarkColIdx;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.sheetName);
    _loadHeaders();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadHeaders() async {
    setState(() => _loadingHeaders = true);
    
    List<String>? headers;
    
    if (widget.service != null) {
      // Use Google Drive API if service is available
      headers = await widget.service!.getSpreadsheetHeaders(widget.sheetId);
    } else {
      // Fallback: use CSV export
      try {
        final response = await http.get(
          Uri.parse(
            'https://docs.google.com/spreadsheets/d/${widget.sheetId}/export?format=csv',
          ),
        );
        
        if (response.statusCode == 200) {
          final csvData = response.body;
          final lines = csvData.split('\n');
          if (lines.isNotEmpty) {
            final headerLine = lines[0];
            headers = headerLine.split(',').map((h) => h.trim()).toList();
          }
        }
      } catch (e) {
        // Handle error
      }
    }
    
    if (!mounted) return;

    int? autoKeyIdx;
    if (headers != null && headers.isNotEmpty) {
      // Auto-detect key column: A column containing "key" or "id" (case-insensitive)
      for (int i = 0; i < headers.length; i++) {
        final header = headers[i].toLowerCase();
        if (header.contains('key') || header.contains('id')) {
          autoKeyIdx = i;
          break;
        }
      }
    }

    setState(() {
      _headers = headers ?? [];
      _loadingHeaders = false;
      if (autoKeyIdx != null) {
        _keyColIdx = autoKeyIdx;
        _sourceColIdx = autoKeyIdx + 1 < _headers.length ? autoKeyIdx + 1 : 0;
        _targetColIdx = autoKeyIdx + 2 < _headers.length ? autoKeyIdx + 2 : (_sourceColIdx + 1 < _headers.length ? _sourceColIdx + 1 : 0);
      } else {
        _sourceColIdx = 0;
        _targetColIdx = _headers.length > 1 ? 1 : 0;
      }
    });
  }

  String _getColumnLabel(int index) {
    if (index < 0 || index >= _headers.length) {
      return String.fromCharCode(65 + index); // A, B, C...
    }
    final header = _headers[index];
    if (header.isEmpty) {
      return String.fromCharCode(65 + index);
    }
    return '${String.fromCharCode(65 + index)}: $header';
  }

  void _confirm() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }
    widget.onConfirm(FlashcardSet(
      title: _titleController.text.trim(),
      sheetId: widget.sheetId,
      frontColIdx: _sourceColIdx,
      backColIdx: _targetColIdx,
      keyColIdx: _keyColIdx ?? -1,
      lastSynced: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: ThemeService.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: ThemeService.getBackgroundColor(isDark),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          color: isDark ? Colors.white : AppColors.cSlate800,
        ),
        title: Text(
          'Configure Sheet',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.cSlate900,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(
                  color: isDark ? AppColors.cSlate400 : AppColors.cSlate600,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
                  ),
                ),
                filled: true,
                fillColor: isDark ? AppColors.cDarkSurface : AppColors.cSlate50,
              ),
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.cSlate900,
              ),
            ),
            const SizedBox(height: 24),
            if (_loadingHeaders)
              const Center(child: CircularProgressIndicator())
            else if (_headers.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No columns found',
                  style: TextStyle(
                    color: isDark ? AppColors.cSlate400 : AppColors.cSlate600,
                  ),
                ),
              )
            else ...[
              _buildColumnSelector(
                'Key Column (optional)',
                _keyColIdx,
                (idx) => setState(() => _keyColIdx = idx == -1 ? null : idx),
                isDark,
                allowNone: true,
              ),
              const SizedBox(height: 16),
              _buildColumnSelector(
                'Source Column',
                _sourceColIdx,
                (idx) => setState(() => _sourceColIdx = idx),
                isDark,
              ),
              const SizedBox(height: 16),
              _buildColumnSelector(
                'Target Column',
                _targetColIdx,
                (idx) => setState(() => _targetColIdx = idx),
                isDark,
              ),
              const SizedBox(height: 16),
              _buildColumnSelector(
                'Remark Column (optional)',
                _remarkColIdx,
                (idx) => setState(() => _remarkColIdx = idx == -1 ? null : idx),
                isDark,
                allowNone: true,
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _confirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.cBrand600,
                  ),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnSelector(
    String label,
    int? selectedIdx,
    ValueChanged<int> onChanged,
    bool isDark, {
    bool allowNone = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.cSlate900,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: selectedIdx ?? (allowNone ? -1 : null),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
              ),
            ),
            filled: true,
            fillColor: isDark ? AppColors.cDarkSurface : AppColors.cSlate50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          dropdownColor: isDark ? AppColors.cDarkSurface : Colors.white,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.cSlate900,
          ),
          items: [
            if (allowNone)
              DropdownMenuItem(
                value: -1,
                child: Text('None'),
              ),
            ...List.generate(_headers.length, (i) {
              return DropdownMenuItem(
                value: i,
                child: Text(_getColumnLabel(i)),
              );
            }),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ],
    );
  }
}
