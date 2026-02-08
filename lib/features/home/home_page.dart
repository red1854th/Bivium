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
import 'package:bivium/features/home/edit_project_page.dart';

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
      loadedSets.sort(
        (a, b) => b.lastAccessed.compareTo(a.lastAccessed),
      ); // Sort by lastAccessed
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
                  // Kebab menu button to navigate to EditProjectPage
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: AppColors.cSlate400),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProjectPage(
                            set: s,
                            allTitles: _sets.map((e) => e.title).toList(),
                            onUpdate: (newTitle, newDescription) {
                              setState(() {
                                s.title = newTitle;
                                s.description = newDescription;
                              });
                              _saveData();
                            },
                            onDelete: () {
                              setState(() {
                                _sets.removeWhere((set) => set.sheetId == s.sheetId);
                              });
                              _saveData();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _navigateToDetail(FlashcardSet s, int index) async {
    // Update lastAccessed before navigating
    setState(() {
      _sets[index].lastAccessed = DateTime.now();
    });
    await _saveData(); // Save the updated access time

    if (!mounted) return;

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
    // Refresh the state when returning from the detail page
    // This will trigger a re-sort if _loadData is called again or if _sets is directly sorted
    setState(() {
      _sets.sort(
        (a, b) => b.lastAccessed.compareTo(a.lastAccessed),
      ); // Sort after returning
    });
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
