import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // Import for compute
import '../../core/theme.dart';
import '../../models/flashcard.dart';
import '../../services/google_drive_service.dart';
import 'add_set_dialog.dart';
import 'setting_page.dart';
import 'package:bivium/features/detail/detail_page.dart';

// Top-level function to parse JSON in an isolate
List<FlashcardSet> _parseFlashcardSets(String setsJson) {
  final List<dynamic> decoded = jsonDecode(setsJson);
  return decoded.map((item) => FlashcardSet.fromJson(item)).toList();
}

class HomePage extends StatefulWidget {
  final VoidCallback? onThemeChanged;
  final SharedPreferences prefs; // Add this field

  const HomePage({
    super.key,
    this.onThemeChanged,
    required this.prefs,
  }); // Modify constructor

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<FlashcardSet> _sets = [];
  bool _isGridView = true;
  bool _isLoading = true; // Add this new state variable
  late final GoogleDriveService _driveService;
  late final SharedPreferences _prefs; // Add this field

  @override
  void initState() {
    super.initState();
    _driveService = GoogleDriveService();
    _prefs = widget.prefs; // Initialize prefs from widget
    // Defer _loadData() until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  // 중복된 제목을 방지하기 위한 메서드 정의
  String uniquifyTitle(String title, List<String> existingTitles) {
    if (!existingTitles.contains(title)) return title;
    int counter = 1;
    String newTitle = "$title ($counter)";
    while (existingTitles.contains(newTitle)) {
      counter++;
      newTitle = "$title ($counter)";
    }
    return newTitle;
  }

  Future<void> _loadData() async {
    // Use the passed prefs instance
    final String? setsJson = _prefs.getString('flashcard_sets');
    if (setsJson != null) {
      // Use compute to parse JSON on a separate isolate
      final List<FlashcardSet> loadedSets = await compute(
        _parseFlashcardSets,
        setsJson,
      );
      setState(() {
        _sets = loadedSets;
        _isLoading = false; // Set to false after data is loaded
      });
    } else {
      setState(() {
        _isLoading = false; // Also set to false if no data was found
      });
    }
  }

  Future<void> _saveData() async {
    // Use the passed prefs instance
    final String encoded = jsonEncode(_sets.map((s) => s.toJson()).toList());
    await _prefs.setString('flashcard_sets', encoded);
    await _prefs.reload();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: ThemeService.getBackgroundColor(isDark),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Image.asset(
                    'assets/icon/app_logo.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "BIVIUM",
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: isDark ? Colors.white : AppColors.cSlate900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.search,
                      color: isDark ? AppColors.cSlate400 : AppColors.cSlate600,
                    ),
                    onPressed: () {
                      // 검색 기능 구현 예정
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.settings_outlined,
                      color: isDark ? AppColors.cSlate400 : AppColors.cSlate600,
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SettingPage(
                            service: _driveService,
                            onThemeChanged: widget.onThemeChanged,
                            prefs:
                                _prefs, // Pass the SharedPreferences instance
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // 2. Project Control Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    "PROJECTS",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.cSlate400 : AppColors.cSlate500,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _isGridView ? Icons.grid_view : Icons.view_list,
                      color: AppColors.cBrand600,
                    ),
                    onPressed: () => setState(() => _isGridView = !_isGridView),
                    tooltip: 'Toggle View',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.cBrand50,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _showAddDialog(context),
                    icon: const Icon(Icons.add, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.cSlate900,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Content List/Grid
            Expanded(
              child:
                  _isLoading // Check _isLoading first
                  ? const Center(
                      child: CircularProgressIndicator(),
                    ) // Show loading indicator
                  : _sets
                        .isEmpty // Only show "No projects yet" if not loading AND no sets
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 48,
                            color: isDark
                                ? AppColors.cSlate600
                                : AppColors.cSlate300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "No projects yet",
                            style: TextStyle(
                              color: AppColors.cSlate400,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => _showAddDialog(context),
                            child: const Text("Create your first project"),
                          ),
                        ],
                      ),
                    )
                  : _isGridView
                  ? _buildGridView()
                  : _buildListView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: _sets.length,
      itemBuilder: (context, index) {
        final s = _sets[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _navigateToDetail(s, index),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cDarkSurface : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.cBrand50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder, color: AppColors.cBrand600),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: isDark ? Colors.white : AppColors.cSlate900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Last synced: ${s.lastSynced.month}/${s.lastSynced.day} ${s.lastSynced.hour}:${s.lastSynced.minute}",
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.cSlate400
                                : AppColors.cSlate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.cSlate400),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemCount: _sets.length,
      itemBuilder: (context, index) {
        final s = _sets[index];
        return InkWell(
          onTap: () => _navigateToDetail(s, index),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cDarkSurface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.cBrand50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.folder,
                        color: AppColors.cBrand600,
                        size: 20,
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.cGreen700,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  s.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: isDark ? Colors.white : AppColors.cSlate900,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  "${s.qcResults.length} issues",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.cRed700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Updated ${s.lastSynced.month}/${s.lastSynced.day}",
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.cSlate400 : AppColors.cSlate500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _navigateToDetail(FlashcardSet s, int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailPage(
          setInfo: s,
          allTitles: _sets.map((e) => e.title).toList(),
          onUpdate: () => _saveData(),
          onDelete: () {
            setState(() => _sets.removeAt(index));
            _saveData();
          },
          driveService: _driveService,
        ),
      ),
    );
    setState(() {});
  }

  void _showAddDialog(BuildContext context) {
    final titles = _sets.map((s) => s.title).toList(); // 변수 미리 선언
    showDialog(
      context: context,
      builder: (_) => AddSetDialog(
        onAdd: (newSet) {
          newSet.title = uniquifyTitle(newSet.title, titles);
          setState(() => _sets.add(newSet));
          _saveData();
        },
        allTitles: titles,
        driveService: _driveService,
      ),
    );
  }
}
