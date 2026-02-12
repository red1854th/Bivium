import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:bivium/services/google_drive_service.dart';

class RemarkPage extends StatefulWidget {
  final GoogleDriveService service;
  final String spreadsheetId;
  final int cardIndex;
  final int columnIdx;
  final String initialRemark;

  const RemarkPage({
    super.key,
    required this.service,
    required this.spreadsheetId,
    required this.cardIndex,
    required this.columnIdx,
    required this.initialRemark,
  });

  @override
  State<RemarkPage> createState() => _RemarkPageState();
}

class _RemarkPageState extends State<RemarkPage> {
  late List<String> _remarkItems;
  final TextEditingController _inputController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _parseRemarks(widget.initialRemark);
  }

  void _parseRemarks(String text) {
    _remarkItems = text
        .split('\n\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _addRemark() async {
    final newText = _inputController.text.trim();
    if (newText.isEmpty) return;

    setState(() => _isSaving = true);

    // 기존 리스트에 새 항목 추가 후 \n\n으로 결합
    final updatedList = List<String>.from(_remarkItems)..add(newText);
    final fullText = updatedList.join('\n\n');

    try {
      final range =
          '${String.fromCharCode(65 + widget.columnIdx)}${widget.cardIndex + 2}';
      await widget.service.updateSpreadsheetCell(
        widget.spreadsheetId,
        range,
        fullText,
      );

      setState(() {
        _remarkItems = updatedList;
        _inputController.clear();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('save_failed_msg'.tr())));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    // 리스트 박스 강조 색상 (브랜드 컬러 또는 포인트 컬러 활용)
    final Color cardBgColor = isDark
        ? Colors.blueGrey.withValues(alpha: 0.2)
        : Colors.blue.withValues(alpha: 0.08);
    final Color borderColor = isDark
        ? Colors.blue.withValues(alpha: 0.4)
        : Colors.blue.withValues(alpha: 0.3);

    return Scaffold(
      appBar: AppBar(title: Text('remark_log'.tr())),

      body: Column(
        children: [
          // 1. 리스트 영역
          Expanded(
            child: _remarkItems.isEmpty
                ? Center(child: Text('no_remarks_msg'.tr()))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _remarkItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, width: 1.5),
                      ),
                      child: Text(
                        _remarkItems[index],
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
          ),
          // 2. 입력 영역 (기존 박스 형태 복구)
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'enter_remark'.tr(),

                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _isSaving
                    ? const SizedBox(
                        width: 48,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_upward,
                            color: Colors.white,
                          ),
                          onPressed: _addRemark,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }
}
