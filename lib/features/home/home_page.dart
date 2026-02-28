import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../models/flashcard.dart';
import '../../services/google_drive_service.dart';
import 'add_set_dialog.dart';
import 'setting_page.dart';
import 'package:bivium/features/detail/detail_page.dart';
import 'package:bivium/features/home/edit_project_page.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:styled_text/styled_text.dart';
import 'widgets/easter_egg_dialog.dart';
import 'home_controller.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../auth/google_login_page.dart';

class ManuscriptLinePainter extends CustomPainter {
  final bool isHorizontal;
  final bool isDark;
  final String seedId;

  ManuscriptLinePainter({
    required this.isHorizontal,
    required this.isDark,
    this.seedId = "",
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double standardWidth = 1.2;

    // 테두리 및 장식선용 Paint (완전 불투명)
    final linePaint = Paint()
      ..color = AppColors.cBrand600.withValues(alpha: 1.0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = standardWidth;

    // 1. 기본 외곽 테두리
    canvas.drawRect(Offset.zero & size, linePaint);

    // 2. 조건별 테두리 및 장식선
    if (isHorizontal) {
      canvas.drawLine(Offset.zero, Offset(0, size.height), linePaint);
      canvas.drawLine(
        Offset(size.width, 0),
        Offset(size.width, size.height),
        linePaint,
      );
      canvas.drawLine(Offset.zero, Offset(size.width, 0), linePaint);
      canvas.drawLine(const Offset(0, 6), Offset(size.width, 6), linePaint);
      canvas.drawLine(
        Offset(0, size.height),
        Offset(size.width, size.height),
        linePaint,
      );
      canvas.drawLine(
        Offset(0, size.height - 6),
        Offset(size.width, size.height - 6),
        linePaint,
      );
    } else {
      canvas.drawLine(Offset.zero, Offset(size.width, 0), linePaint);
      canvas.drawLine(
        Offset(0, size.height),
        Offset(size.width, size.height),
        linePaint,
      );
      canvas.drawLine(Offset.zero, Offset(0, size.height), linePaint);
      canvas.drawLine(const Offset(8, 0), Offset(8, size.height), linePaint);
      canvas.drawLine(
        Offset(size.width, 0),
        Offset(size.width, size.height),
        linePaint,
      );
      canvas.drawLine(
        Offset(size.width - 8, 0),
        Offset(size.width - 8, size.height),
        linePaint,
      );
    }

    // 3. 패턴 그리기 (연한 브랜드 컬러 적용)
    if (seedId.isNotEmpty) {
      final random = Random(seedId.hashCode);
      final patternPaint = Paint()
        ..color = AppColors.cBrand600
            .withValues(alpha: 0.15) // 패턴에만 연하게 처리
        ..style = PaintingStyle.stroke
        ..strokeWidth = standardWidth;

      final double paddingLeft = isHorizontal ? 0.0 : 8.5;
      final double paddingRight = isHorizontal ? 0.0 : 8.5;
      final double paddingTop = isHorizontal ? 6.5 : 0.0;
      final double paddingBottom = isHorizontal ? 6.5 : 0.0;

      final double effectiveHeight = size.height - paddingTop - paddingBottom;
      final double cellSize = effectiveHeight / 4;

      for (int j = 0; j < 4; j++) {
        final double py = paddingTop + (j * cellSize);

        // 좌측 배치 (4, 3, 2, 1)
        int leftCount = 4 - j;
        for (int i = 0; i < leftCount; i++) {
          final double px = paddingLeft + (i * cellSize);
          if (px + cellSize <= size.width - paddingRight) {
            // 1/4 확률(25%)로 패턴을 숨김 (0, 1, 2, 3 중 0일 때 skip)
            if (random.nextInt(5) != 0) {
              _drawSinglePattern(
                canvas,
                random,
                Offset(px, py),
                cellSize,
                patternPaint,
              );
            }
          }
        }

        // 우측 배치 (1, 2, 3, 4)
        int rightCount = j + 1;
        for (int i = 0; i < rightCount; i++) {
          final double px = size.width - paddingRight - ((i + 1) * cellSize);
          if (px >= paddingLeft) {
            // 1/4 확률(25%)로 패턴을 숨김
            if (random.nextInt(5) != 0) {
              _drawSinglePattern(
                canvas,
                random,
                Offset(px, py),
                cellSize,
                patternPaint,
              );
            }
          }
        }
      }
    }
  }

  void _drawSinglePattern(
    Canvas canvas,
    Random random,
    Offset pos,
    double size,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(pos.dx + size / 2, pos.dy + size / 2);
    canvas.rotate(random.nextInt(4) * (pi / 2));
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(-size / 2, -size / 2),
        width: size * 2,
        height: size * 2,
      ),
      0,
      pi / 2,
      false,
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ManuscriptLinePainter oldDelegate) =>
      oldDelegate.seedId != seedId || oldDelegate.isDark != isDark;
}

class HomePage extends StatefulWidget {
  final VoidCallback? onThemeChanged;
  final SharedPreferences prefs;
  final GoogleDriveService driveService;
  final bool initialAuth;

  const HomePage({
    super.key,
    required this.prefs,
    this.onThemeChanged,
    this.initialAuth = false,
    required this.driveService,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeController _controller;
  late final GoogleDriveService _driveService;
  final TextEditingController _searchController = TextEditingController();

  late bool _isAuthenticated = widget.initialAuth;
  late bool _isAuthChecking = !widget.initialAuth;

  @override
  void initState() {
    super.initState();
    _driveService = widget.driveService;
    _controller = HomeController(prefs: widget.prefs);
    _controller.addListener(_onControllerChanged);

    if (_isAuthenticated) {
      _controller.loadData();
      _driveService.signInSilentlyCheck();
    } else {
      _checkAuth();
    }
  }

  Future<void> _checkAuth() async {
    if (!mounted) return;
    setState(() => _isAuthChecking = true);
    try {
      final account = await _driveService.signInSilentlyCheck();
      if (account != null && mounted) {
        setState(() => _isAuthenticated = true);
        await _controller.loadData();
      }
    } finally {
      if (mounted) setState(() => _isAuthChecking = false);
    }
  }

  Future<void> _handleLogin() async {
    final account = await _driveService.signIn();
    if (account != null && mounted) {
      setState(() => _isAuthenticated = true);
      await _controller.loadData();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return Material(color: Colors.transparent, elevation: 0, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isAuthChecking) {
      return Scaffold(
        backgroundColor: ThemeService.getBackgroundColor(isDark),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAuthenticated) {
      return GoogleLoginPage(onLoginPressed: _handleLogin);
    }

    return Scaffold(
      backgroundColor: ThemeService.getBackgroundColor(isDark),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(isDark),
            Expanded(
              child: _controller.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildMainContent(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          if (!_controller.isSearching) ...[
            _buildLogo(isDark),
            const Spacer(),
          ] else ...[
            _buildSearchField(isDark),
            const SizedBox(width: 8),
          ],
          _buildActionButtons(isDark),
        ],
      ),
    );
  }

  Widget _buildLogo(bool isDark) {
    return GestureDetector(
      onTap: () => EasterEggDialog.show(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/icon/app_logo.svg', width: 28, height: 28),
          const SizedBox(width: 12),
          StyledText(
            text: "app_name".tr(),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: isDark ? Colors.white : AppColors.cSlate900,
            ),
            tags: {
              'sub': StyledTextTag(
                style: TextStyle(
                  fontSize: 10,
                  color: isDark
                      ? Colors.white70
                      : AppColors.cSlate900.withValues(alpha: 0.7),
                ),
              ),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isDark) {
    if (_controller.sets.isEmpty) return _buildEmptyState(isDark);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (!_controller.isSearching) ...[
          SliverToBoxAdapter(child: _buildRecentSection(isDark)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
        SliverToBoxAdapter(child: _buildListHeader(isDark)),
        _buildSliverReorderableList(isDark),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildRecentSection(bool isDark) {
    final recentSets = List<FlashcardSet>.from(_controller.sets)
      ..sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));
    final displayRecent = recentSets
        .take(8)
        .where((s) => s.lastAccessed != DateTime.fromMillisecondsSinceEpoch(0))
        .toList();

    if (displayRecent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Text(
            "recent".tr(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.cSlate400 : AppColors.cSlate500,
              letterSpacing: 1.0,
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: displayRecent.length,
            itemBuilder: (context, index) =>
                _buildRecentCard(displayRecent[index], isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentCard(FlashcardSet s, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => _navigateToDetail(s),
        child: CustomPaint(
          painter: ManuscriptLinePainter(
            isHorizontal: true,
            isDark: isDark,
            seedId: s.id,
          ),
          child: Container(
            width: 110,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¶',
                  style: TextStyle(
                    color: AppColors.cBrand600,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  s.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.2,
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

  Widget _buildSliverReorderableList(bool isDark) {
    final filteredSets = _controller.filteredSets;
    return SliverReorderableList(
      itemCount: filteredSets.length,
      proxyDecorator: _proxyDecorator,
      onReorder: (oldIndex, newIndex) {
        if (!_controller.isSearching) {
          _controller.reorderSets(oldIndex, newIndex);
        }
      },
      itemBuilder: (context, index) {
        final setItem = filteredSets[index];
        return Padding(
          key: ValueKey('list_item_${setItem.id}'),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: _buildSetCard(setItem, index, isDark),
        );
      },
    );
  }

  Widget _buildSetCard(FlashcardSet s, int index, bool isDark) {
    return InkWell(
      onTap: () => _navigateToDetail(s),
      child: CustomPaint(
        painter: ManuscriptLinePainter(
          isHorizontal: false,
          isDark: isDark,
          seedId: s.id,
        ),
        child: Container(
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: const EdgeInsets.only(left: 4, right: 12),
          child: Row(
            children: [
              if (!_controller.isSearching)
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: AppColors.cSlate300,
                      size: 20,
                    ),
                  ),
                )
              else
                const SizedBox(width: 44),
              Text(
                '¶',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.cSlate500 : AppColors.cSlate400,
                  fontFamily: 'serif',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppColors.cSlate900,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz, color: AppColors.cSlate400),
                onPressed: () => _showEditProject(s),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return Expanded(
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cDarkSurface : AppColors.cSlate100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.cSlate900,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: "search".tr(),
            hintStyle: TextStyle(
              color: isDark ? AppColors.cSlate500 : AppColors.cSlate400,
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onChanged: (val) => _controller.setSearchQuery(val),
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            _controller.isSearching ? Icons.close : Icons.search,
            color: isDark ? AppColors.cSlate400 : AppColors.cSlate600,
          ),
          onPressed: () {
            _controller.setSearching(!_controller.isSearching);
            if (!_controller.isSearching) _searchController.clear();
          },
        ),
        if (!_controller.isSearching)
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
                    prefs: widget.prefs,
                  ),
                ),
              );
              _checkAuth();
            },
          ),
      ],
    );
  }

  Widget _buildListHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            Text(
              _controller.isSearching
                  ? "search_results".tr()
                  : "all_projects".tr(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.cSlate400 : AppColors.cSlate500,
                letterSpacing: 1.0,
              ),
            ),
            const Spacer(),
            if (!_controller.isSearching)
              SizedBox(
                width: 28,
                height: 28,
                child: IconButton(
                  onPressed: () => _showAddDialog(context),
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.cBrand600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_open, size: 48, color: AppColors.cSlate300),
          const SizedBox(height: 16),
          Text(
            "no_projects".tr(),
            style: const TextStyle(color: AppColors.cSlate400),
          ),
          TextButton(
            onPressed: () => _showAddDialog(context),
            child: Text("create_first".tr()),
          ),
        ],
      ),
    );
  }

  void _showEditProject(FlashcardSet s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProjectPage(
          set: s,
          allTitles: _controller.sets.map((e) => e.title).toList(),
          onUpdate: (t, d) => _controller.updateSet(s.id, t, d),
          onDelete: () => _controller.removeSet(s.id),
        ),
      ),
    );
  }

  Future<void> _navigateToDetail(FlashcardSet s) async {
    _controller.updateLastAccessed(s);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailPage(
          setInfo: s,
          allTitles: _controller.sets.map((e) => e.title).toList(),
          onUpdate: () => _controller.saveData(),
          onDelete: () => _controller.removeSet(s.id),
          driveService: _driveService,
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AddSetDialog(
        onAdd: (n) => _controller.addSet(n),
        allTitles: _controller.sets.map((s) => s.title).toList(),
        driveService: _driveService,
      ),
    );
  }
}
