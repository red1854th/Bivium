import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:bivium/services/google_drive_service.dart';

class RemarkPage extends StatefulWidget {
  final GoogleDriveService service;
  final String spreadsheetId;
  final int cardIndex;
  final int columnIdx;
  final String initialRemark;
  final String? cardKey;
  final String frontText;
  final String backText;

  const RemarkPage({
    super.key,
    required this.service,
    required this.spreadsheetId,
    required this.cardIndex,
    required this.columnIdx,
    required this.initialRemark,
    this.cardKey,
    required this.frontText,
    required this.backText,
  });

  @override
  State<RemarkPage> createState() => _RemarkPageState();
}

class _RemarkPageState extends State<RemarkPage> {
  List<String> _remarkItems = [];
  final TextEditingController _inputController = TextEditingController();
  bool _isSaving = false;
  bool _isLoading = true;

  static const Color cBrand50 = Color(0xFFF0FFF1);
  static const Color cBrand600 = Color(0xFF5AE361);
  static const Color cDarkBg = Color(0xFF0C1D12);
  static const Color cDarkSurface = Color(0xFF1B2B21);
  static const Color cWhiteSurface = Color(0xFFF9FFF9);
  @override
  void initState() {
    super.initState();
    _fetchLatestRemarks();
  }

  Future<void> _fetchLatestRemarks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final range =
        '${String.fromCharCode(65 + widget.columnIdx)}${widget.cardIndex + 2}';
    try {
      final String latestData = await widget.service.getSpreadsheetCell(
        widget.spreadsheetId,
        range,
      );
      _parseRemarks(latestData);
    } catch (e) {
      _parseRemarks(widget.initialRemark);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveToSheets(List<String> updatedList) async {
    setState(() => _isSaving = true);
    final fullText = updatedList.join('\n\n');
    final range =
        '${String.fromCharCode(65 + widget.columnIdx)}${widget.cardIndex + 2}';
    try {
      await widget.service.updateSpreadsheetCell(
        widget.spreadsheetId,
        range,
        fullText,
      );
      setState(() => _remarkItems = updatedList);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('save_failed'.tr())));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _parseRemarks(String text) {
    _remarkItems = text
        .split('\n\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _addRemark() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    await _saveToSheets(List<String>.from(_remarkItems)..add(text));
    _inputController.clear();
  }

  Future<void> _editItem(int index) async {
    final editController = TextEditingController(text: _remarkItems[index]);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('edit'.tr()),
        content: TextField(controller: editController, maxLines: null),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('save'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true && editController.text.trim().isNotEmpty) {
      final list = List<String>.from(_remarkItems);
      list[index] = editController.text.trim();
      await _saveToSheets(list);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _remarkItems.join('\n\n'));
      },
      child: Scaffold(
        backgroundColor: isDark ? cDarkBg : cBrand50,
        appBar: AppBar(
          backgroundColor: isDark ? cDarkSurface : cWhiteSurface,
          elevation: 0,
          title: Text('remark_log'.tr()),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _fetchLatestRemarks,
            ),
          ],
        ),
        body: Column(
          children: [
            // 카드 정보 헤더 (구분선 제거)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? cDarkSurface
                    : cWhiteSurface.withValues(alpha: 0.9),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 인덱스 및 Key 글자 색상을 브랜드 컬러로 변경
                  Text(
                    '#${widget.cardIndex + 1} ${widget.cardKey ?? ""}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: cBrand600, // 브랜드 컬러 적용
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderBox('', widget.frontText),
                      const SizedBox(width: 16),
                      _buildHeaderBox('', widget.backText),
                    ],
                  ),
                ],
              ),
            ),
            // 비고 리스트
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: cBrand600),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _remarkItems.length,
                      itemBuilder: (context, index) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          title: Text(
                            _remarkItems[index],
                            style: const TextStyle(fontSize: 15),
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (val) {
                              if (val == 'edit'.tr()) _editItem(index);
                              if (val == 'delete'.tr()) {
                                _saveToSheets(
                                  List<String>.from(_remarkItems)
                                    ..removeAt(index),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit'.tr(),
                                child: Text('edit'.tr()),
                              ),
                              PopupMenuItem(
                                value: 'delete'.tr(),
                                child: Text(
                                  'delete'.tr(),
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
            _buildBottomInput(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBox(String label, String text) {
    return Expanded(
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildBottomInput(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? cDarkSurface : cWhiteSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              enabled: !_isSaving && !_isLoading,
              decoration: InputDecoration(
                hintText: 'enter_remark'.tr(),
                border: InputBorder.none,
              ),
            ),
          ),
          _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: cBrand600,
                  ),
                )
              : IconButton(
                  onPressed: _isLoading ? null : _addRemark,
                  icon: const Icon(Icons.arrow_upward, color: cBrand600),
                ),
        ],
      ),
    );
  }
}
