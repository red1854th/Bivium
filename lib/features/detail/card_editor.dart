import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bivium/models/flashcard.dart';
import 'package:bivium/services/google_drive_service.dart';
import 'package:bivium/features/detail/remark_page.dart';
import 'package:bivium/core/theme.dart';
import 'package:bivium/features/editor/text_editor.dart';

// 설정 패널 임포트
import 'package:bivium/features/home/widgets/editor_settings_panel.dart';

class CardEditor extends StatefulWidget {
  final Flashcard card;
  final int cardIndex;
  final FlashcardSet setInfo;
  final GoogleDriveService driveService;
  final Function(bool) onSettingsToggle;

  const CardEditor({
    super.key,
    required this.card,
    required this.cardIndex,
    required this.setInfo,
    required this.driveService,
    required this.onSettingsToggle,
  });

  @override
  State<CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<CardEditor> {
  EditorSettings _settings = EditorSettings(
    fontSize: 19.0,
    lineHeight: 1.4,
    fontFamily: 'Pretendard',
  );

  bool _isVertical = true;
  bool _isSettingsOpen = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isVertical = prefs.getBool('is_editor_vertical') ?? true;
      _settings = EditorSettings(
        fontSize: prefs.getDouble('editor_font_size') ?? 19.0,
        lineHeight: prefs.getDouble('editor_line_height') ?? 1.4,
        fontFamily: prefs.getString('editor_font_family') ?? 'Pretendard',
      );
    });
  }

  Future<void> _saveLayoutPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_editor_vertical', value);
  }

  /// 설정창 상태를 변경하고 부모에게 알림
  void _setSettingsOpen(bool open) {
    if (_isSettingsOpen == open) return;
    setState(() => _isSettingsOpen = open);
    widget.onSettingsToggle(open); // 부모(EditCardPage)에게 상태 전달
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color cardBg = widget.card.isFlagged
        ? (isDark
              ? const Color(0xFFFFFF00).withValues(alpha: 0.1)
              : const Color(0xFFFFF9c4))
        : (isDark ? AppColors.cDarkBg : AppColors.cBg);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // [레이어 1] 메인 에디터 카드
        Container(
          margin: const EdgeInsets.fromLTRB(10, 5, 10, 10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Flex(
                  direction: _isVertical ? Axis.vertical : Axis.horizontal,
                  children: [
                    Expanded(
                      child: TextEditor(
                        initialContent: widget.card.front,
                        onChanged: (val) => widget.card.front = val,
                        fontSize: _settings.fontSize,
                        lineHeight: _settings.lineHeight,
                        fontFamily: _settings.fontFamily,
                      ),
                    ),
                    Container(
                      width: _isVertical ? double.infinity : 1,
                      height: _isVertical ? 1 : double.infinity,
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                    Expanded(
                      child: TextEditor(
                        initialContent: widget.card.back,
                        onChanged: (val) => widget.card.back = val,
                        fontSize: _settings.fontSize,
                        lineHeight: _settings.lineHeight,
                        fontFamily: _settings.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              _buildBottomToolbar(context),
            ],
          ),
        ),

        // [레이어 2] 딤 레이어 + 터치 차단막 (부모 핸들까지 덮음)
        if (_isSettingsOpen)
          Positioned.fill(
            top: -100,
            bottom: -100,
            left: -50,
            right: -50,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _setSettingsOpen(false),
              onHorizontalDragUpdate: (details) {
                if (details.delta.dx > 8) _setSettingsOpen(false);
              },
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),
          ),

        // [레이어 3] 설정 패널
        EditorSettingsPanel(
          isVisible: _isSettingsOpen,
          currentSettings: _settings,
          card: widget.card,
          cardIndex: widget.cardIndex,
          onSettingsChanged: (newSettings) {
            setState(() => _settings = newSettings);
          },
          onClose: () => _setSettingsOpen(false),
        ),
      ],
    );
  }

  Widget _buildBottomToolbar(BuildContext context) {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark; // 여기서 다시 정의

    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _iconAction(
            icon: Icons.history_edu_rounded,
            color: (widget.card.remark.trim().isNotEmpty)
                ? AppColors.cBrand600
                : Colors.grey,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RemarkPage(
                    service: widget.driveService,
                    spreadsheetId: widget.setInfo.sheetId,
                    cardIndex: widget.cardIndex,
                    columnIdx: widget.setInfo.remarkColIdx,
                    initialRemark: widget.card.remark,
                  ),
                ),
              );
              if (mounted) setState(() {});
            },
          ),
          _iconAction(
            icon: widget.card.isFlagged ? Icons.flag : Icons.flag_outlined,
            color: widget.card.isFlagged ? Colors.orange : Colors.grey,
            onTap: () =>
                setState(() => widget.card.isFlagged = !widget.card.isFlagged),
          ),
          _iconAction(
            onTap: () {
              final newValue = !_isVertical;
              setState(() => _isVertical = newValue);
              _saveLayoutPreference(newValue);
            },
            child: RotatedBox(
              quarterTurns: _isVertical ? 0 : 1,
              child: const Icon(
                Icons.view_agenda_rounded,
                size: 20,
                color: Colors.grey,
              ),
            ),
          ),
          _iconAction(
            icon: Icons.more_vert_rounded,
            onTap: () => _setSettingsOpen(true),
          ),
        ],
      ),
    );
  }

  Widget _iconAction({
    IconData? icon,
    Color color = Colors.grey,
    required VoidCallback onTap,
    Widget? child,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Center(child: child ?? Icon(icon, size: 20, color: color)),
      ),
    );
  }
}
