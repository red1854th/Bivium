import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

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
        _folderError = 'check_connection_error'.tr();
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
    if (diff.inDays == 0) return 'today'.tr();
    if (diff.inDays == 1) return 'yesterday'.tr();
    if (diff.inDays < 7) return 'days_ago'.tr(args: [diff.inDays.toString()]);

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
              ? (_folderStack.isEmpty ? 'google_drive'.tr() : 'folder'.tr())
              : 'recent_spreadsheets'.tr(),
        ),
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
      items: [
        BottomNavigationBarItem(
          icon: const Icon(Icons.folder_outlined),
          label: 'my_drive'.tr(),
        ),
        BottomNavigationBarItem(
          icon: const Icon(Icons.list_alt),
          label: 'spreadsheets'.tr(),
        ),
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
          title: Text(
            item.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          subtitle: item.isFolder
              ? null
              : Text(
                  _formatModified(item.modifiedTime),
                  style: TextStyle(
                    color: isDark ? AppColors.cSlate400 : AppColors.cSlate500,
                    fontSize: 12,
                  ),
                ),
          trailing: item.isFolder
              ? const Icon(Icons.chevron_right, size: 20)
              : null,
          onTap: () => item.isFolder
              ? _openFolder(item)
              : _handleSheetSelection(item.id, item.name),
        );
      },
    );
  }

  Widget _buildListBody(bool isDark) {
    if (_listLoading) return const Center(child: CircularProgressIndicator());
    if (_listItems.isEmpty) return Center(child: Text('no_files_found'.tr()));

    return ListView.builder(
      itemCount: _listItems.length,
      itemBuilder: (context, index) {
        final file = _listItems[index];
        return ListTile(
          leading: const Icon(Icons.table_chart, color: AppColors.cBrand600),
          title: Text(
            file.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            _formatModified(file.modifiedTime),
            style: TextStyle(
              color: isDark ? AppColors.cSlate400 : AppColors.cSlate500,
              fontSize: 12,
            ),
          ),
          onTap: () => _handleSheetSelection(file.id, file.name),
        );
      },
    );
  }
}
