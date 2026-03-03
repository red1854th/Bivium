import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/theme.dart';
import '../../services/google_drive_service.dart';

class RemarkSettingPage extends StatefulWidget {
  final GoogleDriveService service;
  final String spreadsheetId;
  final Function(int) onConfirm;

  const RemarkSettingPage({
    super.key,
    required this.service,
    required this.spreadsheetId,
    required this.onConfirm,
  });

  @override
  State<RemarkSettingPage> createState() => _RemarkSettingPageState();
}

class _RemarkSettingPageState extends State<RemarkSettingPage> {
  List<String> _headers = [];
  bool _isLoading = true;
  int? _selectedIdx;

  @override
  void initState() {
    super.initState();
    _loadHeaders();
  }

  Future<void> _loadHeaders() async {
    setState(() => _isLoading = true);
    final info = await widget.service.getSpreadsheetInfo(widget.spreadsheetId);
    if (!mounted) return;

    if (info != null) {
      setState(() {
        _headers = info.headers;
        _isLoading = false;

        // Auto-detect remark column if possible
        for (int i = 0; i < _headers.length; i++) {
          final h = _headers[i].toLowerCase();
          if (h.contains('remark') || h.contains('note') || h.contains('비고')) {
            _selectedIdx = i;
            break;
          }
        }
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  String _getColumnLabel(int index) {
    if (index < 0 || index >= _headers.length) {
      return String.fromCharCode(65 + index);
    }
    final header = _headers[index];
    return '${String.fromCharCode(65 + index)}: ${header.isEmpty ? "Column ${index + 1}" : header}';
  }

  void _handleConfirm() {
    if (_selectedIdx != null) {
      widget.onConfirm(_selectedIdx!);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.cDarkBg : AppColors.cBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'remark_page_setup'.tr(),
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.cSlate900,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: isDark ? Colors.white : AppColors.cSlate900,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.cBrand600),
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.cBrand600.withValues(alpha: 0.1)
                          : AppColors.cBrand600.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.cBrand600.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: AppColors.cBrand600,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'remark_setup_description'.tr(),
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.cSlate300
                                  : AppColors.cSlate700,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'select_remark_column'.tr(),
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.cSlate900,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedIdx,
                    dropdownColor: isDark
                        ? AppColors.cDarkSurface
                        : Colors.white,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? AppColors.cDarkSurface : Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.cDarkBorder
                              : AppColors.cSlate200,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.cBrand600,
                          width: 2,
                        ),
                      ),
                    ),
                    items: List.generate(_headers.length, (i) {
                      return DropdownMenuItem(
                        value: i,
                        child: Text(
                          _getColumnLabel(i),
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.cSlate900,
                          ),
                        ),
                      );
                    }),
                    onChanged: (val) => setState(() => _selectedIdx = val),
                    hint: Text('choose_column'.tr()),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _selectedIdx == null ? null : _handleConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cBrand600,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isDark
                            ? Colors.white10
                            : Colors.black12,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'confirm'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
    );
  }
}
