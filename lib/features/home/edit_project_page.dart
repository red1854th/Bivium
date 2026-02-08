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
    _titleController.removeListener(_validateTitle);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _validateTitle() {
    final newTitle = _titleController.text.trim();
    if (newTitle.isEmpty) {
      setState(() {
        _titleErrorText = '제목은 비워둘 수 없습니다.';
      });
    } else if (widget.allTitles.contains(newTitle) &&
        newTitle != widget.set.title) {
      setState(() {
        _titleErrorText = '이미 사용 중인 제목입니다.';
      });
    } else {
      setState(() {
        _titleErrorText = null;
      });
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.cDarkSurface : Colors.white,
          title: Text(
            '프로젝트 삭제',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: Text(
            '정말로 "${widget.set.title}" 프로젝트를 삭제하시겠습니까?',
            style: TextStyle(
              color: isDark ? AppColors.cSlate300 : AppColors.cSlate700,
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text(
                '취소',
                style: TextStyle(
                  color: isDark ? AppColors.cSlate400 : AppColors.cSlate600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                widget.onDelete();
                Navigator.of(context).pop(); // Close the dialog
                Navigator.of(context).pop(); // Go back to the home page
              },
              child: const Text('삭제', style: TextStyle(color: Colors.white)),
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
      backgroundColor: ThemeService.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: ThemeService.getBackgroundColor(isDark),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.set.title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.save,
              color:
                  (_titleErrorText == null &&
                      _titleController.text.trim().isNotEmpty)
                  ? Theme.of(context).primaryColor
                  : (isDark ? AppColors.cSlate600 : AppColors.cSlate400),
            ),
            onPressed:
                _titleErrorText == null &&
                    _titleController.text.trim().isNotEmpty
                ? () {
                    widget.onUpdate(
                      _titleController.text.trim(),
                      _descriptionController.text.trim(),
                    );
                    Navigator.of(context).pop(); // Go back to the home page
                  }
                : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Text(
              '제목',
              style: TextStyle(
                color: isDark ? AppColors.cSlate400 : AppColors.cSlate700,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: '프로젝트 제목을 입력하세요', // Placeholder text
                hintStyle: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black38,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                fillColor: isDark ? AppColors.cDarkSurface : Colors.white,
                filled: true,
                errorText: _titleErrorText,
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 16),
            Text(
              '설명',
              style: TextStyle(
                color: isDark ? AppColors.cSlate400 : AppColors.cSlate700,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: '프로젝트 설명을 입력하세요', // Placeholder text
                hintStyle: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black38,
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                fillColor: isDark ? AppColors.cDarkSurface : Colors.white,
                filled: true,
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => _showDeleteConfirmationDialog(context),
                icon: const Icon(Icons.delete_forever, color: Colors.white),
                label: const Text(
                  '프로젝트 삭제',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
