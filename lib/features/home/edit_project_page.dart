import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/flashcard.dart';

class EditProjectPage extends StatefulWidget {
  final FlashcardSet set;
  final List<String> allTitles;
  final Function(String newTitle, String newDescription) onUpdate;
  final VoidCallback onDelete;

  const EditProjectPage({
    super.key,
    required this.set,
    required this.allTitles,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<EditProjectPage> createState() => _EditProjectPageState();
}

class _EditProjectPageState extends State<EditProjectPage> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  String? _titleErrorText;

  bool get _isSaveEnabled {
    final title = _titleController.text.trim();
    return title.isNotEmpty && _titleErrorText == null;
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.set.title);
    _descriptionController = TextEditingController(
      text: widget.set.description,
    );
    _titleController.addListener(_validateTitle);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _validateTitle() {
    final newTitle = _titleController.text.trim();

    setState(() {
      if (newTitle.isEmpty) {
        _titleErrorText = '제목은 비워둘 수 없습니다.';
      } else if (widget.allTitles.contains(newTitle) &&
          newTitle != widget.set.title) {
        _titleErrorText = '이미 사용 중인 제목입니다.';
      } else {
        _titleErrorText = null;
      }
    });
  }

  void _handleSave() {
    if (!_isSaveEnabled) return;

    final finalTitle = _titleController.text.trim();
    final finalDesc = _descriptionController.text.trim();

    widget.onUpdate(finalTitle, finalDesc);
    Navigator.of(context).pop();
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.cDarkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '프로젝트 삭제',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '정말로 "${widget.set.title}" 프로젝트를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.',
            style: TextStyle(
              color: isDark ? AppColors.cSlate300 : AppColors.cSlate700,
              height: 1.5,
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '취소',
                style: TextStyle(
                  color: isDark ? AppColors.cSlate400 : AppColors.cSlate600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                // 삭제 처리 실행
                widget.onDelete();
                // 홈 화면(첫 번째 경로)까지 모든 스택을 제거하여 즉시 이동
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text(
                '삭제',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.cDarkBg : AppColors.cBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.cDarkBg : AppColors.cBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '프로젝트 편집',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.save,
              color: _isSaveEnabled
                  ? AppColors.cBrand600
                  : (isDark ? AppColors.cSlate600 : AppColors.cSlate400),
            ),
            onPressed: _isSaveEnabled ? _handleSave : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('제목', isDark),
            const SizedBox(height: 8),
            _buildTextField(
              _titleController,
              '제목을 입력하세요',
              isDark,
              error: _titleErrorText,
            ),
            const SizedBox(height: 24),
            _buildLabel('설명', isDark),
            const SizedBox(height: 8),
            _buildTextField(
              _descriptionController,
              '설명을 입력하세요',
              isDark,
              maxLines: 5,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.9),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _showDeleteConfirmationDialog(context),
                icon: const Icon(Icons.delete_forever, color: Colors.white),
                label: const Text(
                  '프로젝트 삭제',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        color: isDark ? AppColors.cSlate400 : AppColors.cSlate700,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    bool isDark, {
    int maxLines = 1,
    String? error,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        errorText: error,
        fillColor: isDark ? AppColors.cDarkSurface : Colors.white,
        filled: true,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.cBrand600, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
    );
  }
}
