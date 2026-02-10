import 'package:flutter/material.dart';
import 'package:bivium/models/flashcard.dart';
import 'package:bivium/services/google_drive_service.dart';
import 'package:bivium/features/detail/remark_page.dart';
import 'package:bivium/core/theme.dart';
import 'package:bivium/features/editor/text_editor.dart';

class CardEditor extends StatefulWidget {
  final Flashcard card;
  final int cardIndex;
  final FlashcardSet setInfo;
  final GoogleDriveService driveService;

  const CardEditor({
    super.key,
    required this.card,
    required this.cardIndex,
    required this.setInfo,
    required this.driveService,
  });

  @override
  State<CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<CardEditor> {
  double _fontSize = 19.0;
  double _lineHeight = 1.4;
  String _fontFamily = 'Pretendard';
  final List<String> _fonts = ['Pretendard', 'Roboto', 'NeoDGM'];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color cardBg = widget.card.isFlagged
        ? (isDark ? const Color(0xFF4D4000) : const Color(0xFFFFF9C4))
        : (isDark ? AppColors.cDarkBg : AppColors.cBg);

    return Container(
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: Column(
                children: [
                  Expanded(
                    child: TextEditor(
                      initialContent: widget.card.front,
                      onChanged: (val) => widget.card.front = val,
                      fontSize: _fontSize,
                      lineHeight: _lineHeight,
                      fontFamily: _fontFamily,
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: TextEditor(
                      initialContent: widget.card.back,
                      onChanged: (val) => widget.card.back = val,
                      fontSize: _fontSize,
                      lineHeight: _lineHeight,
                      fontFamily: _fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildBottomToolbar(context),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.02),
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
          _iconAction(Icons.history_edu_rounded, Colors.grey, () {
            Navigator.push(
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
          }),
          _iconAction(
            widget.card.isFlagged ? Icons.flag : Icons.flag_outlined,
            widget.card.isFlagged ? Colors.orange : Colors.grey,
            () =>
                setState(() => widget.card.isFlagged = !widget.card.isFlagged),
          ),
          _iconAction(Icons.ios_share_rounded, Colors.grey, () {}),
          _iconAction(
            Icons.more_vert_rounded,
            Colors.grey,
            () => _showSettingsMenu(context),
          ),
        ],
      ),
    );
  }

  void _showSettingsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "에디터 설정",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildSettingRow("글자 크기", _fontSize.toStringAsFixed(0), () {
                    setModalState(
                      () => _fontSize = (_fontSize >= 30) ? 14 : _fontSize + 2,
                    );
                    setState(() {});
                  }),
                  _buildSettingRow("줄 간격", _lineHeight.toStringAsFixed(1), () {
                    setModalState(
                      () => _lineHeight = (_lineHeight >= 2.0)
                          ? 1.0
                          : _lineHeight + 0.2,
                    );
                    setState(() {});
                  }),
                  const SizedBox(height: 15),
                  const Text(
                    "폰트 선택",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: _fonts.map((font) {
                      return ChoiceChip(
                        label: Text(font, style: TextStyle(fontFamily: font)),
                        selected: _fontFamily == font,
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() => _fontFamily = font);
                            setState(() {});
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingRow(String title, String value, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      trailing: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _iconAction(IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}
