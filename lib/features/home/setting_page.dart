import 'package:flutter/cupertino.dart';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme.dart';
import '../../core/locales.dart';
import '../../services/google_drive_service.dart';
import '../../models/substitution.dart';
import '../../models/glossary_item.dart';

class SettingPage extends StatefulWidget {
  final GoogleDriveService service;
  final VoidCallback? onThemeChanged;
  final SharedPreferences prefs;

  const SettingPage({
    super.key,
    required this.service,
    this.onThemeChanged,
    required this.prefs,
  });

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  bool _isLoading = true;
  GoogleSignInAccount? _account;
  bool _isDarkMode = false;
  late final SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = widget.prefs;
    _loadAccount();
    _loadThemeMode();
  }

  Future<void> _loadAccount() async {
    setState(() => _isLoading = true);
    final account = widget.service.currentUser;
    setState(() {
      _account = account;
      _isLoading = false;
    });
  }

  Future<void> _loadThemeMode() {
    final isDark = ThemeService.isDarkMode(_prefs);
    setState(() {
      _isDarkMode = isDark;
    });
    return Future.value();
  }

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    final account = await widget.service.signIn();
    setState(() {
      _account = account;
      _isLoading = false;
    });
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    await widget.service.signOut();
    setState(() {
      _account = null;
      _isLoading = false;
    });
  }

  Future<void> _toggleDarkMode(bool value) async {
    setState(() {
      _isDarkMode = value;
    });
    await ThemeService.setDarkMode(_prefs, value);
    widget.onThemeChanged?.call();
  }

  // 언어 선택 시트 호출 함수
  void _showLanguagePicker(BuildContext context, bool isDark) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('language_settings'.tr()),
        actions: AppLocale.supported.map((appLocale) {
          final isSelected = context.locale == appLocale.locale;
          return CupertinoActionSheetAction(
            onPressed: () {
              context.setLocale(appLocale.locale);
              Navigator.pop(context);
            },
            // 현재 선택된 언어는 볼드체로 강조
            child: Text(
              appLocale.displayName,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.cBrand600 : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 현재 설정된 언어의 표시 이름 찾기
    final currentLanguageName = AppLocale.supported
        .firstWhere(
          (e) => e.locale == context.locale,
          orElse: () => AppLocale.supported.first,
        )
        .displayName;

    return Scaffold(
      backgroundColor: ThemeService.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: ThemeService.getBackgroundColor(isDark),
        surfaceTintColor: ThemeService.getBackgroundColor(isDark),
        elevation: 0,
        title: Text(
          'settings'.tr(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.cSlate900,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 다크 모드 설정
                  _buildSettingTile(
                    isDark,
                    icon: Icons.dark_mode,
                    label: 'dark_mode'.tr(),
                    trailing: Switch(
                      value: _isDarkMode,
                      onChanged: _toggleDarkMode,
                      activeThumbColor: AppColors.cBrand600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 언어 설정 (Dropdown 대신 모달 호출 방식)
                  _buildSettingTile(
                    isDark,
                    icon: Icons.language,
                    label: 'language_settings'.tr(),
                    onTap: () => _showLanguagePicker(context, isDark),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          currentLanguageName,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppColors.cSlate400
                                : AppColors.cSlate500,
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: AppColors.cSlate400,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildSettingTile(
                    isDark,
                    icon: Icons.find_replace,
                    label: 'text_substitution_settings'.tr(),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SubstitutionManagementPage(
                            prefs: _prefs,
                            isGlobal: true,
                          ),
                        ),
                      );
                      setState(() {});
                    },
                    trailing: const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.cSlate400,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'account'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.cSlate400 : AppColors.cSlate500,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 계정 정보 섹션
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _tileDecoration(isDark),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: isDark
                              ? AppColors.cSlate700
                              : AppColors.cSlate100,
                          backgroundImage: account?.photoUrl != null
                              ? NetworkImage(account!.photoUrl!)
                              : null,
                          child: account?.photoUrl == null
                              ? Icon(
                                  Icons.person,
                                  color: isDark
                                      ? AppColors.cSlate400
                                      : AppColors.cSlate600,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account?.displayName ?? 'not_signed_in'.tr(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.cSlate900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                account?.email ?? 'sign_in_desc'.tr(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.cSlate400
                                      : AppColors.cSlate500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 로그인/로그아웃 버튼
                  SizedBox(
                    width: double.infinity,
                    child: account == null
                        ? ElevatedButton(
                            onPressed: _signIn,
                            style: _buttonStyle(isDark, isPrimary: true),
                            child: Text(
                              'sign_in_with_google'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : OutlinedButton(
                            onPressed: _signOut,
                            style: _buttonStyle(isDark, isPrimary: false),
                            child: Text(
                              'sign_out'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  // InkWell을 추가하여 타일 전체 클릭 가능하게 변경
  Widget _buildSettingTile(
    bool isDark, {
    required IconData icon,
    required String label,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // vertical 패딩을 줄이거나 조정하여 고정 높이 내에서 중앙 정렬되게 합니다.
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // 타일의 최소 높이를 56으로 고정 (Switch의 기본 높이와 유사하게 맞춤)
        constraints: const BoxConstraints(minHeight: 70),
        decoration: _tileDecoration(isDark),
        child: Row(
          children: [
            Icon(icon, color: isDark ? Colors.white : AppColors.cSlate600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.cSlate900,
                ),
              ),
            ),
            // trailing 위젯이 중앙에 오도록 배치
            Center(child: trailing),
          ],
        ),
      ),
    );
  }

  BoxDecoration _tileDecoration(bool isDark) => BoxDecoration(
    color: isDark ? AppColors.cDarkSurface : Colors.white,
    border: Border.all(
      color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
    ),
    borderRadius: BorderRadius.circular(12),
  );

  ButtonStyle _buttonStyle(bool isDark, {required bool isPrimary}) {
    if (isPrimary) {
      return ElevatedButton.styleFrom(
        backgroundColor: AppColors.cBrand600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
    }
    return OutlinedButton.styleFrom(
      foregroundColor: isDark ? Colors.white : AppColors.cSlate900,
      side: BorderSide(
        color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}

class SpaceVisualizerController extends TextEditingController {
  SpaceVisualizerController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> children = [];
    final text = value.text;
    for (int i = 0; i < text.length; i++) {
      if (text[i] == ' ') {
        children.add(
          TextSpan(
            text: '·',
            style: style?.copyWith(
              color: AppColors.cBrand600.withValues(alpha: 0.5),
            ),
          ),
        );
      } else {
        children.add(TextSpan(text: text[i], style: style));
      }
    }
    return TextSpan(children: children, style: style);
  }
}

abstract class ManageableItem {
  String get group;
  String get id;
  bool get isActive;
  ManageableItem copyWith({String? group, bool? isActive});
  Map<String, dynamic> toJson();
}

class GenericManagementPage<T extends ManageableItem> extends StatefulWidget {
  final SharedPreferences prefs;
  final bool isGlobal;
  final List<T>? projectItems;
  final Function(List<T>)? onSaveProject;
  final String title;
  final String storageKey;
  final T Function(Map<String, dynamic>) fromJson;
  final String Function(List<T>) serialize;
  final List<T> Function(String) deserialize;
  final Widget Function(
    T item,
    int index,
    bool isGlobal,
    bool isDark,
    VoidCallback onEdit,
    VoidCallback onDelete,
  )
  itemBuilder;
  final Future<T?> Function(BuildContext context, T? existing) onAddOrEdit;
  final bool showGlobal;

  const GenericManagementPage({
    super.key,
    required this.prefs,
    required this.isGlobal,
    this.projectItems,
    this.onSaveProject,
    required this.title,
    required this.storageKey,
    required this.fromJson,
    required this.serialize,
    required this.deserialize,
    required this.itemBuilder,
    required this.onAddOrEdit,
    this.showGlobal = true,
  });

  @override
  State<GenericManagementPage<T>> createState() =>
      _GenericManagementPageState<T>();
}

class _GenericItemRow<T> {
  final String? groupHeader;
  final T? item;
  final int? index;
  _GenericItemRow({this.groupHeader, this.item, this.index});
  bool get isHeader => groupHeader != null;
}

class _GenericManagementPageState<T extends ManageableItem>
    extends State<GenericManagementPage<T>> {
  late List<T> _globalItems;
  late List<T> _projectItems;
  final Set<String> _collapsedGroups = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  void _loadAll() {
    final globalJson = widget.prefs.getString(widget.storageKey) ?? '[]';
    _globalItems = widget.deserialize(globalJson);
    _projectItems = List.from(widget.projectItems ?? []);
  }

  void _saveGlobal() {
    widget.prefs.setString(widget.storageKey, widget.serialize(_globalItems));
  }

  void _saveProject() {
    widget.onSaveProject?.call(_projectItems);
  }

  List<_GenericItemRow<T>> _getFlatList(List<T> source) {
    final Map<String, List<int>> groupMap = {};
    for (int i = 0; i < source.length; i++) {
      final g = source[i].group.isEmpty ? 'ungrouped'.tr() : source[i].group;
      groupMap.putIfAbsent(g, () => []).add(i);
    }
    final List<_GenericItemRow<T>> flat = [];
    final seenGroups = <String>[];
    for (var s in source) {
      final g = s.group.isEmpty ? 'ungrouped'.tr() : s.group;
      if (!seenGroups.contains(g)) seenGroups.add(g);
    }
    for (var gn in seenGroups) {
      flat.add(_GenericItemRow(groupHeader: gn));
      if (!_collapsedGroups.contains(gn)) {
        for (var idx in groupMap[gn]!) {
          flat.add(_GenericItemRow(item: source[idx], index: idx));
        }
      }
    }
    return flat;
  }

  void _onReorder(int oldIdx, int newIdx, List<T> source, bool isGlobal) {
    final flat = _getFlatList(source);
    if (newIdx > oldIdx) newIdx--;
    final moved = flat[oldIdx];
    setState(() {
      if (moved.isHeader) {
        final groupName = moved.groupHeader!;
        final itemsToMove = source
            .where(
              (s) =>
                  (s.group.isEmpty ? 'ungrouped'.tr() : s.group) == groupName,
            )
            .toList();
        source.removeWhere(
          (s) => (s.group.isEmpty ? 'ungrouped'.tr() : s.group) == groupName,
        );
        int insertPos;
        if (newIdx == 0) {
          insertPos = 0;
        } else {
          final neighbor = flat[newIdx];
          if (neighbor.isHeader) {
            insertPos = source.indexWhere(
              (s) =>
                  (s.group.isEmpty ? 'ungrouped'.tr() : s.group) ==
                  neighbor.groupHeader,
            );
            if (insertPos == -1) insertPos = source.length;
          } else {
            insertPos =
                source.indexOf(neighbor.item!) + (newIdx > oldIdx ? 1 : 0);
          }
        }
        source.insertAll(insertPos.clamp(0, source.length), itemsToMove);
      } else {
        final item = source.removeAt(moved.index!);
        int targetInsertPos;
        String? targetGroup;
        if (newIdx == 0) {
          targetInsertPos = 0;
          targetGroup = flat.firstWhere((e) => e.isHeader).groupHeader;
        } else {
          for (int i = newIdx; i >= 0; i--) {
            if (flat[i].isHeader) {
              targetGroup = flat[i].groupHeader;
              break;
            }
          }
          final neighbor = flat[newIdx];
          if (neighbor.isHeader) {
            targetInsertPos = source.indexWhere(
              (s) =>
                  (s.group.isEmpty ? 'ungrouped'.tr() : s.group) ==
                  neighbor.groupHeader,
            );
            if (targetInsertPos == -1) targetInsertPos = source.length;
          } else {
            targetInsertPos =
                source.indexOf(neighbor.item!) + (newIdx > oldIdx ? 1 : 0);
          }
        }
        final updatedItem =
            item.copyWith(
                  group:
                      (targetGroup == null || targetGroup == 'ungrouped'.tr())
                      ? ''
                      : targetGroup,
                )
                as T;
        source.insert(targetInsertPos.clamp(0, source.length), updatedItem);
      }
      isGlobal ? _saveGlobal() : _saveProject();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: ThemeService.getBackgroundColor(isDark),
      appBar: AppBar(
        backgroundColor: ThemeService.getBackgroundColor(isDark),
        title: Text(widget.title),
      ),
      body: CustomScrollView(
        slivers: [
          if (!widget.isGlobal) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildSectionHeader(
                  'project_setting'.tr(), // Generic label better
                  isDark,
                  () => _handleEdit(null, null, false),
                ),
              ),
            ),
            _buildReorderableSliverList(_projectItems, false, isDark),
            if (widget.showGlobal) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _buildSectionHeader(
                    'global_setting'.tr(),
                    isDark,
                    () => _handleEdit(null, null, true),
                  ),
                ),
              ),
              _buildReorderableSliverList(_globalItems, true, isDark),
            ],
          ] else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _buildSectionHeader(
                  'global_setting'.tr(),
                  isDark,
                  () => _handleEdit(null, null, true),
                ),
              ),
            ),
            _buildReorderableSliverList(_globalItems, true, isDark),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark, VoidCallback onAdd) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.cSlate400 : AppColors.cSlate600,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 20),
          onPressed: onAdd,
          color: AppColors.cBrand600,
        ),
      ],
    );
  }

  Future<void> _handleEdit(T? existing, int? index, bool isGlobal) async {
    final result = await widget.onAddOrEdit(context, existing);
    if (result != null) {
      setState(() {
        final list = isGlobal ? _globalItems : _projectItems;
        if (index != null) {
          list[index] = result;
        } else {
          list.add(result);
        }
        isGlobal ? _saveGlobal() : _saveProject();
      });
    }
  }

  Widget _buildReorderableSliverList(List<T> list, bool isGlobal, bool isDark) {
    if (list.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            (T == Substitution)
                ? 'no_substitutions'.tr()
                : 'no_glossary_items'.tr(),
            style: const TextStyle(color: AppColors.cSlate400, fontSize: 13),
          ),
        ),
      );
    }
    final flat = _getFlatList(list);
    return SliverReorderableList(
      itemCount: flat.length,
      onReorder: (oldIdx, newIdx) => _onReorder(oldIdx, newIdx, list, isGlobal),
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, ch) {
            final double animValue = Curves.easeInOut.transform(
              animation.value,
            );
            final double elevation = lerpDouble(0, 8, animValue)!;
            return Material(
              elevation: elevation,
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1 * animValue),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
        );
      },
      itemBuilder: (context, index) {
        final itemRow = flat[index];
        if (itemRow.isHeader) {
          final groupName = itemRow.groupHeader!;
          final isCollapsed = _collapsedGroups.contains(groupName);
          return ReorderableDelayedDragStartListener(
            key: ValueKey('header_${isGlobal}_$groupName'),
            index: index,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.cDarkSurface.withValues(alpha: 0.5)
                    : AppColors.cSlate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.05),
                  width: 1,
                ),
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    isCollapsed
                        ? _collapsedGroups.remove(groupName)
                        : _collapsedGroups.add(groupName);
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isCollapsed
                            ? Icons.keyboard_arrow_right_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: AppColors.cBrand600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        groupName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.cSlate300
                              : AppColors.cSlate700,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.drag_handle_rounded,
                        size: 20,
                        color: AppColors.cSlate400,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          return ReorderableDelayedDragStartListener(
            key: ValueKey('item_${isGlobal}_${itemRow.item!.id}'),
            index: index,
            child: widget.itemBuilder(
              itemRow.item!,
              itemRow.index!,
              isGlobal,
              isDark,
              () => _handleEdit(itemRow.item, itemRow.index, isGlobal),
              () {
                setState(() {
                  list.removeAt(itemRow.index!);
                  isGlobal ? _saveGlobal() : _saveProject();
                });
              },
            ),
          );
        }
      },
    );
  }
}

class SubstitutionManagementPage extends StatelessWidget {
  final SharedPreferences prefs;
  final bool isGlobal;
  final List<Substitution>? projectSubstitutions;
  final Function(List<Substitution>)? onSaveProject;

  const SubstitutionManagementPage({
    super.key,
    required this.prefs,
    required this.isGlobal,
    this.projectSubstitutions,
    this.onSaveProject,
  });

  @override
  Widget build(BuildContext context) {
    return GenericManagementPage<Substitution>(
      prefs: prefs,
      isGlobal: isGlobal,
      projectItems: projectSubstitutions,
      onSaveProject: onSaveProject,
      title: 'text_substitution_settings'.tr(),
      storageKey: 'global_substitutions',
      fromJson: (json) => Substitution.fromJson(json),
      serialize: (list) => Substitution.serializeList(list),
      deserialize: (json) => Substitution.deserializeList(json),
      onAddOrEdit: (context, existing) => _showSubstitutionDialog(
        context,
        existing,
        isGlobal,
        prefs,
        projectSubstitutions ?? [],
      ),
      itemBuilder: (item, index, isGlobal, isDark, onEdit, onDelete) =>
          _buildSubstitutionTile(
            item,
            index,
            isGlobal,
            isDark,
            onEdit,
            onDelete,
          ),
    );
  }

  Widget _buildSubstitutionTile(
    Substitution sub,
    int index,
    bool isGlobal,
    bool isDark,
    VoidCallback onEdit,
    VoidCallback onDelete,
  ) {
    String visualize(String text) => text.replaceAll(' ', '·');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cDarkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
            width: 0.5,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          dense: true,
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.cBrand600.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.text_fields_rounded,
              size: 16,
              color: AppColors.cBrand600,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  visualize(sub.pattern),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.cSlate200 : AppColors.cSlate800,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: AppColors.cSlate400,
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Text(
                  visualize(sub.replacement),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.cBrand600,
                  ),
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                color: AppColors.cSlate400,
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: Colors.redAccent,
                ),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.drag_handle_rounded,
                size: 20,
                color: AppColors.cSlate300,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Substitution?> _showSubstitutionDialog(
    BuildContext context,
    Substitution? existing,
    bool isGlobal,
    SharedPreferences prefs,
    List<Substitution> projectSubstitutions,
  ) async {
    final patternController = SpaceVisualizerController(
      text: existing?.pattern ?? '',
    );
    final replacementController = SpaceVisualizerController(
      text: existing?.replacement ?? '',
    );
    String selectedGroup = existing?.group ?? '';

    // Load all groups
    final globalJson = prefs.getString('global_substitutions') ?? '[]';
    final globalSubs = Substitution.deserializeList(globalJson);
    final allGroups = <String>{''};
    for (var s in globalSubs) {
      allGroups.add(s.group);
    }
    for (var s in projectSubstitutions) {
      allGroups.add(s.group);
    }
    final groupList = allGroups.toList()..sort();

    return showDialog<Substitution>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? AppColors.cDarkSurface : Colors.white,
              title: Text(
                existing == null
                    ? (isGlobal
                          ? 'add_global_substitution'.tr()
                          : 'add_project_substitution'.tr())
                    : (isGlobal
                          ? 'edit_global_substitution'.tr()
                          : 'edit_project_substitution'.tr()),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: patternController,
                    decoration: InputDecoration(
                      labelText: 'pattern_label'.tr(),
                      hintText: 'e.g. ㅎㅅㅇ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: replacementController,
                    decoration: InputDecoration(
                      labelText: 'replacement_label'.tr(),
                      hintText: 'e.g. 하세요',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'group_label'.tr(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.cSlate400,
                    ),
                  ),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: groupList.contains(selectedGroup)
                        ? selectedGroup
                        : '',
                    items: [
                      ...groupList.map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text(g.isEmpty ? 'ungrouped'.tr() : g),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'NEW_GROUP_ACTION',
                        child: Text(
                          '+ ${'add_new_group'.tr()}',
                          style: const TextStyle(color: AppColors.cBrand600),
                        ),
                      ),
                    ],
                    onChanged: (val) async {
                      if (val == 'NEW_GROUP_ACTION') {
                        final newGroupName = await _showNewGroupDialog(context);
                        if (newGroupName != null && newGroupName.isNotEmpty) {
                          setDialogState(() {
                            if (!groupList.contains(newGroupName)) {
                              groupList.add(newGroupName);
                              groupList.sort();
                            }
                            selectedGroup = newGroupName;
                          });
                        }
                      } else {
                        setDialogState(() => selectedGroup = val ?? '');
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('cancel'.tr()),
                ),
                TextButton(
                  onPressed: () {
                    final pattern = patternController.text;
                    final replacement = replacementController.text;
                    if (pattern.isEmpty || replacement.isEmpty) return;
                    Navigator.pop(
                      context,
                      Substitution(
                        pattern: pattern,
                        replacement: replacement,
                        group: selectedGroup,
                      ),
                    );
                  },
                  child: Text(existing == null ? 'add'.tr() : 'save'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

Future<String?> _showNewGroupDialog(BuildContext context) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return AlertDialog(
        backgroundColor: isDark ? AppColors.cDarkSurface : Colors.white,
        title: Text('add_new_group'.tr()),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: 'group_name_hint'.tr()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('add'.tr()),
          ),
        ],
      );
    },
  );
}

class GlossaryManagementPage extends StatelessWidget {
  final SharedPreferences prefs;
  final bool isGlobal;
  final List<GlossaryItem>? projectGlossary;
  final Function(List<GlossaryItem>)? onSaveProject;

  const GlossaryManagementPage({
    super.key,
    required this.prefs,
    required this.isGlobal,
    this.projectGlossary,
    this.onSaveProject,
  });

  @override
  Widget build(BuildContext context) {
    return GenericManagementPage<GlossaryItem>(
      prefs: prefs,
      isGlobal: isGlobal,
      projectItems: projectGlossary,
      onSaveProject: onSaveProject,
      title: 'glossary_settings'.tr(),
      storageKey: 'global_glossary',
      showGlobal: false,
      fromJson: (json) => GlossaryItem.fromJson(json),
      serialize: (list) => GlossaryItem.serializeList(list),
      deserialize: (json) => GlossaryItem.deserializeList(json),
      onAddOrEdit: (context, existing) => _showGlossaryDialog(
        context,
        existing,
        isGlobal,
        prefs,
        projectGlossary ?? [],
      ),
      itemBuilder: (item, index, isGlobal, isDark, onEdit, onDelete) =>
          _buildGlossaryTile(item, index, isGlobal, isDark, onEdit, onDelete),
    );
  }

  Widget _buildGlossaryTile(
    GlossaryItem item,
    int index,
    bool isGlobal,
    bool isDark,
    VoidCallback onEdit,
    VoidCallback onDelete,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? AppColors.cDarkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: Color(int.parse(item.color.replaceFirst('#', '0xFF'))),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                item.source,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.cSlate900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: AppColors.cSlate400,
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: Text(
                item.targets.join(', '),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.cBrand600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
              color: AppColors.cSlate400,
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: Colors.redAccent,
              ),
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.drag_handle_rounded,
              size: 20,
              color: AppColors.cSlate300,
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Future<GlossaryItem?> _showGlossaryDialog(
    BuildContext context,
    GlossaryItem? existing,
    bool isGlobal,
    SharedPreferences prefs,
    List<GlossaryItem> projectItems,
  ) async {
    final sourceController = TextEditingController(
      text: existing?.source ?? '',
    );
    final targetsController = TextEditingController(
      text: existing?.targets.join(', ') ?? '',
    );
    final hexController = TextEditingController(
      text: (existing?.color ?? '#4FC1FF').toUpperCase().replaceFirst('#', ''),
    );
    String selectedColor = existing?.color ?? '#4FC1FF';
    String selectedGroup = existing?.group ?? '';

    // Extract groups from projectItems
    final List<String> groupList =
        projectItems.map((e) => e.group).toSet().toList()..sort();
    if (!groupList.contains('')) groupList.insert(0, '');

    // Expanded preset colors
    final List<String> presetColors = [
      '#4FC1FF',
      '#FF5555',
      '#55FF55',
      '#FFB74D',
      '#BA68C8',
      '#4DB6AC',
      '#7986CB',
      '#A1887F',
      '#F44336',
      '#E91E63',
      '#9C27B0',
      '#673AB7',
      '#3F51B5',
      '#2196F3',
      '#03A9F4',
      '#00BCD4',
      '#009688',
      '#4CAF50',
      '#8BC34A',
      '#CDDC39',
      '#FFEB3B',
      '#FFC107',
      '#FF9800',
      '#FF5722',
    ];

    return showDialog<GlossaryItem>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            void updateColor(String hex) {
              setDialogState(() {
                if (!hex.startsWith('#')) hex = '#$hex';
                if (hex.length == 7 || hex.length == 9) {
                  selectedColor = hex;
                  hexController.text = hex.toUpperCase().replaceFirst('#', '');
                }
              });
            }

            return AlertDialog(
              backgroundColor: isDark ? AppColors.cDarkSurface : Colors.white,
              title: Text(
                existing == null
                    ? 'add_glossary_item'.tr()
                    : 'edit_glossary_item'.tr(),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: sourceController,
                      decoration: InputDecoration(
                        labelText: 'source_label'.tr(),
                        hintText: 'e.g. apple',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: targetsController,
                      decoration: InputDecoration(
                        labelText: 'targets_label'.tr(),
                        hintText: '사과, 아오리',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'group_label'.tr(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.cSlate400,
                      ),
                    ),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: groupList.contains(selectedGroup)
                          ? selectedGroup
                          : '',
                      items: [
                        ...groupList.map(
                          (g) => DropdownMenuItem(
                            value: g,
                            child: Text(g.isEmpty ? 'ungrouped'.tr() : g),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'NEW_GROUP_ACTION',
                          child: Text(
                            '+ ${'add_new_group'.tr()}',
                            style: const TextStyle(color: AppColors.cBrand600),
                          ),
                        ),
                      ],
                      onChanged: (val) async {
                        if (val == 'NEW_GROUP_ACTION') {
                          final newGroupName = await _showNewGroupDialog(
                            context,
                          );
                          if (newGroupName != null && newGroupName.isNotEmpty) {
                            setDialogState(() {
                              if (!groupList.contains(newGroupName)) {
                                groupList.add(newGroupName);
                                groupList.sort();
                              }
                              selectedGroup = newGroupName;
                            });
                          }
                        } else {
                          setDialogState(() => selectedGroup = val ?? '');
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'color_label'.tr(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.cSlate400,
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Color(
                              int.parse(
                                selectedColor.replaceFirst('#', '0xFF'),
                              ),
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120, // Grid view area
                      width: 280,
                      child: GridView.count(
                        crossAxisCount: 6,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: presetColors.map((colorStr) {
                          final color = Color(
                            int.parse(colorStr.replaceFirst('#', '0xFF')),
                          );
                          final isSelected =
                              selectedColor.toUpperCase() ==
                              colorStr.toUpperCase();
                          return GestureDetector(
                            onTap: () => updateColor(colorStr),
                            child: Container(
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? (isDark ? Colors.white : Colors.black)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: hexController,
                      decoration: InputDecoration(
                        labelText: 'Hex Color',
                        prefixText: '#',
                        hintText: 'FFFFFF',
                        suffixIcon: Icon(
                          Icons.colorize,
                          size: 16,
                          color: AppColors.cBrand600,
                        ),
                      ),
                      onChanged: (val) {
                        String hex = val.startsWith('#') ? val : '#$val';
                        if (RegExp(
                          r'^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$',
                        ).hasMatch(hex)) {
                          setDialogState(() => selectedColor = hex);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('cancel'.tr()),
                ),
                TextButton(
                  onPressed: () {
                    final source = sourceController.text.trim();
                    final targets = targetsController.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();
                    if (source.isEmpty) return;
                    Navigator.pop(
                      context,
                      GlossaryItem(
                        id:
                            existing?.id ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        source: source,
                        targets: targets,
                        color: selectedColor,
                        group: selectedGroup,
                      ),
                    );
                  },
                  child: Text(existing == null ? 'add'.tr() : 'save'.tr()),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
