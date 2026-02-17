import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:async'; // Debounce를 위해 추가

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
  int _currentTabIndex = 0;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce; // 서버 부하를 줄이기 위한 디바운스
  String _searchQuery = '';

  // 데이터 상태
  List<DriveItem> _folderItems = [];
  List<SheetFile> _listItems = [];
  bool _isLoading = true;
  String? _error;

  final List<({String id, String name})> _folderStack = [];

  String? get _currentFolderId =>
      _folderStack.isEmpty ? null : _folderStack.last.id;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // 통합 데이터 로딩 로직
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_searchQuery.isEmpty) {
        // 검색어가 없을 때는 기존 폴더/리스트 로직
        if (_currentTabIndex == 0) {
          _folderItems = await widget.service.getFolderContents(
            _currentFolderId,
          );
        } else {
          _listItems = await widget.service.getSpreadsheets();
        }
      } else {
        // 검색어가 있을 때는 하위 요소 포함 서버 검색
        // 서비스에 하위 검색 기능이 있다고 가정하거나 getSpreadsheets에 쿼리 전달
        _folderItems = await widget.service.searchAllContents(_searchQuery);
        _listItems = await widget.service.searchSpreadsheets(_searchQuery);
      }
    } catch (e) {
      _error = 'check_connection_error'.tr();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 검색어 입력 시 호출 (디바운스 적용)
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() => _searchQuery = query);
      _loadData(); // 서버에 검색 요청
    });
  }

  void _openFolder(DriveItem folder) {
    setState(() {
      _folderStack.add((id: folder.id, name: folder.name));
      _searchQuery = '';
      _searchController.clear();
    });
    _loadData();
  }

  void _goBackFolder() {
    if (_folderStack.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _folderStack.removeLast();
      _searchQuery = '';
      _searchController.clear();
    });
    _loadData();
  }

  void _jumpToFolder(int index) {
    setState(() {
      if (index == -1) {
        _folderStack.clear();
      } else {
        _folderStack.removeRange(index + 1, _folderStack.length);
      }
      _searchQuery = '';
      _searchController.clear();
    });
    _loadData();
  }

  String _formatModified(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(targetDate).inDays;

    if (diffDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diffDays == 1) {
      return 'yesterday'.tr();
    } else if (diffDays < 7) {
      return 'days_ago'.tr(args: [diffDays.toString()]);
    } else {
      return '${dt.year}.${dt.month}.${dt.day}';
    }
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
        ),
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: _buildSearchBar(isDark),
        ),
      ),
      body: Column(
        children: [
          if (_currentTabIndex == 0 && _searchQuery.isEmpty)
            _buildBreadcrumbs(isDark),
          if (_searchQuery.isNotEmpty) _buildSearchHeader(isDark),
          const Divider(height: 1, thickness: 0.5),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_currentTabIndex == 0
                      ? _buildMyDriveBody(isDark)
                      : _buildListBody(isDark)),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomTabs(isDark),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cSlate800 : AppColors.cSlate100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _searchController,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : Colors.black,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.cancel, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          hintText: 'search'.tr(),
          hintStyle: TextStyle(
            color: isDark ? AppColors.cSlate500 : AppColors.cSlate400,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(right: 16),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildSearchHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      width: double.infinity,
      color: isDark ? AppColors.cSlate900 : AppColors.cSlate50,
      child: Text(
        'search_result_for'.tr(args: [_searchQuery]),
        style: TextStyle(
          fontSize: 12,
          color: AppColors.cBrand600,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs(bool isDark) {
    return Container(
      height: 40,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _breadcrumbItem(
            label: 'google_drive'.tr(),
            onTap: () => _jumpToFolder(-1),
            isDark: isDark,
          ),
          ...List.generate(_folderStack.length, (index) {
            return Row(
              children: [
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: isDark ? AppColors.cSlate600 : AppColors.cSlate400,
                ),
                _breadcrumbItem(
                  label: _folderStack[index].name,
                  onTap: () => _jumpToFolder(index),
                  isDark: isDark,
                  isLast: index == _folderStack.length - 1,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _breadcrumbItem({
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
              color: isLast
                  ? AppColors.cBrand600
                  : (isDark ? AppColors.cSlate400 : AppColors.cSlate600),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyDriveBody(bool isDark) {
    if (_error != null) return Center(child: Text(_error!));
    if (_folderItems.isEmpty) return Center(child: Text('no_files_found'.tr()));
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

  Widget _buildBottomTabs(bool isDark) {
    return BottomNavigationBar(
      currentIndex: _currentTabIndex,
      backgroundColor: ThemeService.getBackgroundColor(isDark),
      selectedItemColor: AppColors.cBrand600,
      unselectedItemColor: isDark ? AppColors.cSlate400 : AppColors.cSlate600,
      onTap: (idx) {
        setState(() {
          _currentTabIndex = idx;
          _searchQuery = '';
          _searchController.clear();
        });
        _loadData();
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
}
