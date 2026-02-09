import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/flashcard.dart';
import '../../services/google_drive_service.dart';
import 'sheet_selection_dialog.dart';

class DriveSheetsListPage extends StatefulWidget {
  final GoogleDriveService service;

  const DriveSheetsListPage({super.key, required this.service});

  static Future<({String id, String name, FlashcardSet set})?> open(
    BuildContext context,
    GoogleDriveService service,
  ) async {
    return Navigator.of(
      context,
    ).push<({String id, String name, FlashcardSet set})?>(
      MaterialPageRoute(builder: (_) => DriveSheetsListPage(service: service)),
    );
  }

  @override
  State<DriveSheetsListPage> createState() => _DriveSheetsListPageState();
}

class _DriveSheetsListPageState extends State<DriveSheetsListPage> {
  int _currentTabIndex = 0; // 0 = My Drive, 1 = List
  bool _isGridView = true;

  // My Drive 데이터
  List<DriveItem> _folderItems = [];
  bool _folderLoading = true;
  String? _folderError;
  final List<String> _folderStack = [];

  // List 데이터
  List<SheetFile> _listItems = [];
  bool _listLoading = false;

  String? get _currentFolderId =>
      _folderStack.isEmpty ? null : _folderStack.last;

  @override
  void initState() {
    super.initState();
    _loadFolder(null);
  }

  Future<void> _loadFolder(String? folderId) async {
    if (!mounted) return;
    setState(() {
      _folderLoading = true;
      _folderError = null;
    });

    final items = await widget.service.getFolderContents(folderId);

    if (!mounted) return;
    setState(() {
      _folderItems = items;
      _folderLoading = false;
      if (items.isEmpty && folderId == null) {
        _folderError = '계정 연결 상태를 확인해 주세요.';
      }
    });
  }

  Future<void> _loadSpreadsheetList() async {
    setState(() => _listLoading = true);
    final list = await widget.service.getSpreadsheets();
    if (!mounted) return;
    setState(() {
      _listItems = list;
      _listLoading = false;
    });
  }

  void _openFolder(DriveItem folder) {
    _folderStack.add(folder.id);
    _loadFolder(folder.id);
  }

  void _goBackFolder() {
    if (_folderStack.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    _folderStack.removeLast();
    _loadFolder(_currentFolderId);
  }

  /// 공통 시트 선택 로직
  Future<void> _handleSheetSelection(String id, String name) async {
    final set = await Navigator.of(context).push<FlashcardSet>(
      MaterialPageRoute(
        builder: (_) => SheetSelectionDialog(
          sheetId: id,
          sheetName: name,
          service: widget.service,
          onConfirm: (res) => Navigator.of(context).pop(res),
        ),
      ),
    );
    if (!mounted || set == null) return;
    Navigator.of(context).pop((id: id, name: name, set: set));
  }

  String _formatModified(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.year}.${dt.month}.${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: ThemeService.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: ThemeService.getBackgroundColor(isDark),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _currentTabIndex == 0
              ? _goBackFolder
              : () => Navigator.of(context).pop(),
        ),
        title: Text(
          _currentTabIndex == 0
              ? (_folderStack.isEmpty ? 'Google Drive' : 'Folder')
              : 'Spreadsheets',
        ),
        actions: [
          if (_currentTabIndex == 1 && _listItems.isNotEmpty)
            IconButton(
              icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
              onPressed: () => setState(() => _isGridView = !_isGridView),
            ),
        ],
      ),
      body: _currentTabIndex == 0
          ? _buildMyDriveBody(isDark)
          : _buildListBody(isDark),
      bottomNavigationBar: _buildBottomTabs(isDark),
    );
  }

  Widget _buildBottomTabs(bool isDark) {
    return BottomNavigationBar(
      currentIndex: _currentTabIndex,
      backgroundColor: ThemeService.getBackgroundColor(isDark),
      selectedItemColor: AppColors.cBrand600,
      unselectedItemColor: isDark ? AppColors.cSlate400 : AppColors.cSlate600,
      onTap: (idx) {
        setState(() => _currentTabIndex = idx);
        if (idx == 1 && _listItems.isEmpty && !_listLoading) {
          _loadSpreadsheetList();
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.folder_outlined),
          label: 'My Drive',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'List'),
      ],
    );
  }

  Widget _buildMyDriveBody(bool isDark) {
    if (_folderLoading) return const Center(child: CircularProgressIndicator());
    if (_folderError != null) return Center(child: Text(_folderError!));

    return ListView.builder(
      itemCount: _folderItems.length,
      itemBuilder: (context, index) {
        final item = _folderItems[index];
        return ListTile(
          leading: Icon(
            item.isFolder ? Icons.folder : Icons.table_chart,
            color: item.isFolder ? AppColors.cSlate500 : AppColors.cBrand600,
          ),
          title: Text(item.name),
          trailing: item.isFolder ? const Icon(Icons.chevron_right) : null,
          onTap: () => item.isFolder
              ? _openFolder(item)
              : _handleSheetSelection(item.id, item.name),
        );
      },
    );
  }

  Widget _buildListBody(bool isDark) {
    if (_listLoading) return const Center(child: CircularProgressIndicator());
    if (_listItems.isEmpty) return const Center(child: Text('파일이 없습니다.'));

    if (_isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.8,
        ),
        itemCount: _listItems.length,
        itemBuilder: (context, index) => _SheetCard(
          file: _listItems[index],
          isDark: isDark,
          onTap: () => _handleSheetSelection(
            _listItems[index].id,
            _listItems[index].name,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _listItems.length,
      itemBuilder: (context, index) {
        final file = _listItems[index];
        return ListTile(
          title: Text(file.name),
          subtitle: Text(_formatModified(file.modifiedTime)),
          onTap: () => _handleSheetSelection(file.id, file.name),
        );
      },
    );
  }
}

/// 그리드 뷰에서 A1:C3 데이터를 보여주는 카드 위젯
class _SheetCard extends StatelessWidget {
  final SheetFile file;
  final bool isDark;
  final VoidCallback onTap;

  const _SheetCard({
    required this.file,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cDarkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 미리보기 영역 (A1:C3 데이터 시뮬레이션)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey[100],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(11),
                  ),
                ),
                child: file.previewData != null && file.previewData!.isNotEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: file.previewData!
                            .take(3)
                            .map(
                              (text) => Text(
                                text,
                                style: const TextStyle(
                                  fontSize: 10,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                      )
                    : const Center(
                        child: Icon(
                          Icons.table_chart,
                          size: 30,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            // 하단 파일명 영역
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
