import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/flashcard.dart';
import '../../services/google_drive_service.dart';
import 'sheet_selection_dialog.dart';

/// Google Drive browser: YouTube-style bottom tabs (My Drive / List), grid/list toggle with A1:C3 preview.
class DriveSheetsListPage extends StatefulWidget {
  final GoogleDriveService service;

  const DriveSheetsListPage({super.key, required this.service});

  static Future<({String id, String name, FlashcardSet set})?> open(
    BuildContext context,
    GoogleDriveService service,
  ) async {
    return Navigator.of(context).push<({String id, String name, FlashcardSet set})?>(
      MaterialPageRoute(
        builder: (_) => DriveSheetsListPage(service: service),
      ),
    );
  }

  @override
  State<DriveSheetsListPage> createState() => _DriveSheetsListPageState();
}

class _DriveSheetsListPageState extends State<DriveSheetsListPage> {
  int _currentTabIndex = 0; // 0 = My Drive, 1 = List
  bool _isGridView = true; // grid (checkerboard) vs list for List tab

  // My Drive tab
  List<DriveItem> _folderItems = [];
  bool _folderLoading = true;
  String? _folderError;
  final List<String> _folderStack = [];

  // List tab
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
        _folderError =
            'Sign in or check Google account access in Settings.';
      }
    });
  }

  Future<void> _loadSpreadsheetList() async {
    setState(() {
      _listLoading = true;
    });

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

  void _selectSpreadsheetFromDrive(DriveItem item) async {
    final set = await Navigator.of(context).push<FlashcardSet>(
      MaterialPageRoute(
        builder: (_) => SheetSelectionDialog(
          sheetId: item.id,
          sheetName: item.name,
          service: widget.service,
          onConfirm: (set) => Navigator.of(context).pop(set),
        ),
      ),
    );
    if (!mounted || set == null) return;
    Navigator.of(context).pop((id: item.id, name: item.name, set: set));
  }

  void _selectSpreadsheetFromList(SheetFile file) async {
    final set = await Navigator.of(context).push<FlashcardSet>(
      MaterialPageRoute(
        builder: (_) => SheetSelectionDialog(
          sheetId: file.id,
          sheetName: file.name,
          service: widget.service,
          onConfirm: (set) => Navigator.of(context).pop(set),
        ),
      ),
    );
    if (!mounted || set == null) return;
    Navigator.of(context).pop((id: file.id, name: file.name, set: set));
  }

  String _formatModified(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.month}/${dt.day}/${dt.year}';
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
          onPressed: _currentTabIndex == 0
              ? _goBackFolder
              : () => Navigator.of(context).pop(),
          color: isDark ? Colors.white : AppColors.cSlate800,
        ),
        title: Text(
          _currentTabIndex == 0
              ? (_folderStack.isEmpty ? 'Google Drive' : 'Folder')
              : 'Spreadsheets',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.cSlate900,
          ),
        ),
        actions: [
          if (_currentTabIndex == 1 && _listItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: Icon(
                  _isGridView ? Icons.view_list : Icons.grid_view,
                  color: AppColors.cBrand600,
                ),
                onPressed: () => setState(() => _isGridView = !_isGridView),
                tooltip: _isGridView ? 'List' : 'Grid',
              ),
            ),
        ],
      ),
      body: _currentTabIndex == 0
          ? _buildMyDriveBody(isDark)
          : _buildListBody(isDark),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: ThemeService.getBackgroundColor(isDark),
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.folder_outlined,
                  label: 'My Drive',
                  isSelected: _currentTabIndex == 0,
                  isDark: isDark,
                  onTap: () => setState(() => _currentTabIndex = 0),
                ),
                _NavItem(
                  icon: Icons.list_alt,
                  label: 'List',
                  isSelected: _currentTabIndex == 1,
                  isDark: isDark,
                  onTap: () {
                    setState(() => _currentTabIndex = 1);
                    if (_listItems.isEmpty && !_listLoading) {
                      _loadSpreadsheetList();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyDriveBody(bool isDark) {
    if (_folderLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_folderError != null) {
      return _buildErrorState(isDark, _folderError!);
    }
    if (_folderItems.isEmpty) {
      return Center(
        child: Text(
          'This folder is empty.',
          style: TextStyle(
            color: isDark ? AppColors.cSlate400 : AppColors.cSlate600,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _folderItems.length,
      itemBuilder: (context, index) {
        final item = _folderItems[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isDark ? AppColors.cDarkSurface : AppColors.cSlate100,
            child: Icon(
              item.isFolder ? Icons.folder_outlined : Icons.table_chart_outlined,
              color: item.isFolder ? AppColors.cSlate600 : AppColors.cBrand600,
            ),
          ),
          title: Text(
            item.name,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : AppColors.cSlate900,
            ),
          ),
          trailing: item.isFolder
              ? Icon(Icons.chevron_right, color: AppColors.cSlate400)
              : null,
          onTap: () {
            if (item.isFolder) {
              _openFolder(item);
            } else if (item.isSpreadsheet) {
              _selectSpreadsheetFromDrive(item);
            }
          },
        );
      },
    );
  }

  Widget _buildListBody(bool isDark) {
    if (_listItems.isEmpty && !_listLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.list_alt, size: 48, color: AppColors.cSlate400),
            const SizedBox(height: 16),
            Text(
              'Your spreadsheets (newest first)',
              style: TextStyle(
                color: isDark ? AppColors.cSlate400 : AppColors.cSlate600,
              ),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _loadSpreadsheetList,
              icon: const Icon(Icons.refresh),
              label: const Text('Load list'),
            ),
          ],
        ),
      );
    }
    if (_listLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_listItems.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: _listItems.length,
        itemBuilder: (context, index) {
          final file = _listItems[index];
          return _SheetCard(
            file: file,
            isDark: isDark,
            onTap: () => _selectSpreadsheetFromList(file),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _listItems.length,
      itemBuilder: (context, index) {
        final file = _listItems[index];
        return SizedBox(
          height: 72, // Fixed height
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isDark ? AppColors.cDarkSurface : AppColors.cSlate100,
              child: Icon(Icons.table_chart_outlined, color: AppColors.cBrand600),
            ),
            title: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : AppColors.cSlate900,
              ),
            ),
            subtitle: Text(
              _formatModified(file.modifiedTime),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.cSlate400 : AppColors.cSlate500,
              ),
            ),
            onTap: () => _selectSpreadsheetFromList(file),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(bool isDark, String message) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.cSlate400),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppColors.cSlate400 : AppColors.cSlate600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected ? AppColors.cBrand600 : (isDark ? AppColors.cSlate400 : AppColors.cSlate600),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.cBrand600 : (isDark ? AppColors.cSlate400 : AppColors.cSlate600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cDarkSurface : Colors.white,
        border: Border.all(
          color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.table_chart_outlined,
                  size: 32,
                  color: AppColors.cBrand600,
                ),
                const SizedBox(height: 12),
                Text(
                  file.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.cSlate900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
