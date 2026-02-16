import 'dart:async';
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
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../auth/google_login_page.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onThemeChanged;
  final SharedPreferences prefs;
  final GoogleDriveService driveService;
  final bool initialAuth; // 추가: main에서 받은 초기 인증 상태

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

  // 기존 bool _isAuthenticated = false; 를 아래처럼 수정
  late bool _isAuthenticated = widget.initialAuth;

  // 기존 bool _isAuthChecking = true; 를 아래처럼 수정
  late bool _isAuthChecking = !widget.initialAuth;

  @override
  void initState() {
    super.initState();
    _driveService = GoogleDriveService();
    _controller = HomeController(prefs: widget.prefs);
    _controller.addListener(_onControllerChanged);

    // 수정된 로직: 로그인 의향이 있다면 일단 데이터를 로드(낙관적 UI)하고,
    // 백그라운드에서 실제 세션 유효성을 확인합니다.
    if (_isAuthenticated) {
      _controller.loadData();
      _driveService.signInSilentlyCheck().then((account) {
        if (account == null && mounted) {
          // 세션이 만료되었거나 유효하지 않다면 로그인 페이지로 전환
          setState(() {
            _isAuthenticated = false;
          });
        }
      });
    } else {
      _checkAuth();
    }
  }

  /// [수정] 앱 실행 시 조용히 로그인을 시도하여 세션을 복구합니다.
  Future<void> _checkAuth() async {
    if (!mounted) return;

    setState(() {
      _isAuthChecking = true;
    });

    try {
      // 1. 기존 로컬 토큰 확인 및 안드로이드 계정 자동 로그인 시도
      final account = await _driveService.signInSilentlyCheck();

      // 2. 계정이 확인되면 인증된 것으로 간주
      if (account != null) {
        if (mounted) {
          setState(() {
            _isAuthenticated = true;
          });
        }
        // 3. 인증 성공 시 데이터 로드
        await _controller.loadData();
      } else {
        // 인증 실패 시 로그인 페이지로 유도
        if (mounted) {
          setState(() {
            _isAuthenticated = false;
          });
        }
      }
    } catch (e) {
      debugPrint("인증 확인 중 오류 발생: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isAuthChecking = false;
        });
      }
    }
  }

  /// [수정] 수동 로그인 핸들러
  Future<void> _handleLogin() async {
    try {
      final account = await _driveService.signIn();
      if (account != null && mounted) {
        setState(() {
          _isAuthenticated = true;
        });
        await _controller.loadData();
      }
    } catch (e) {
      debugPrint("로그인 에러: $e");
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

  // 드래그 중 그림자를 제거하기 위한 데코레이터
  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return Material(
      color: Colors.transparent,
      elevation: 0, // 그림자 제거
      child: child,
    );
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
            Expanded(child: _buildMainContent(isDark)),
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

  Widget _buildMainContent(bool isDark) {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.sets.isEmpty) {
      return _buildEmptyState(isDark);
    }

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

  Widget _buildSliverReorderableList(bool isDark) {
    final filteredSets = _controller.filteredSets;

    if (filteredSets.isEmpty && _controller.searchQuery.isNotEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Text(
              "no_search_results".tr(),
              style: TextStyle(color: AppColors.cSlate400),
            ),
          ),
        ),
      );
    }

    return SliverReorderableList(
      itemCount: filteredSets.length,
      proxyDecorator: _proxyDecorator,
      onReorder: (oldIndex, newIndex) {
        if (_controller.isSearching || oldIndex == newIndex) return;
        _controller.reorderSets(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final setItem = filteredSets[index];
        // 꾹 누르는 기능(DelayedListener)을 제거하고 일반 위젯으로 반환
        return Padding(
          key: ValueKey('set_${setItem.id}'),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: _buildSetCard(setItem, index, isDark),
        );
      },
    );
  }

  Widget _buildSetCard(FlashcardSet s, int index, bool isDark) {
    return Material(
      color: isDark ? AppColors.cDarkSurface : Colors.white,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navigateToDetail(s),
        splashColor: AppColors.cBrand600.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.only(left: 4, right: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
            ),
          ),
          child: Row(
            children: [
              if (!_controller.isSearching)
                ReorderableDragStartListener(
                  index: index,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {},
                      onTapDown: (_) => HapticFeedback.lightImpact(),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          color: AppColors.cSlate300,
                          size: 20,
                        ),
                      ),
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

  Widget _buildLogo(bool isDark) {
    return GestureDetector(
      onTap: () => EasterEggDialog.show(context),
      behavior: HitTestBehavior.opaque,
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
            if (_controller.isSearching) {
              _searchController.clear();
              _controller.setSearching(false);
            } else {
              _controller.setSearching(true);
            }
          },
        ),
        if (!_controller.isSearching)
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: isDark ? AppColors.cSlate400 : AppColors.cSlate600,
            ),
            onPressed: () async {
              // 설정 페이지 이동 후 돌아왔을 때 인증 상태를 다시 확인합니다.
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

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open,
            size: 48,
            color: isDark ? AppColors.cSlate600 : AppColors.cSlate300,
          ),
          const SizedBox(height: 16),
          Text(
            "no_projects".tr(),
            style: TextStyle(color: AppColors.cSlate400),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _showAddDialog(context),
            child: Text("create_first".tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildListHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
            IconButton(
              onPressed: () => _showAddDialog(context),
              icon: const Icon(Icons.add, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.cSlate900,
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(32, 32),
              ),
            ),
        ],
      ),
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
    return Container(
      width: 110,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: isDark ? AppColors.cDarkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _navigateToDetail(s),
          splashColor: AppColors.cBrand600.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.cBrand50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '¶',
                    style: TextStyle(
                      color: AppColors.cBrand600,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
