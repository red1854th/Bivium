import 'package:flutter/material.dart';
import 'package:bivium/models/flashcard.dart';
import 'package:bivium/services/google_drive_service.dart';
import 'package:bivium/features/detail/remark_page.dart';
import 'package:bivium/core/theme.dart';

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
  late TextEditingController _frontController;
  late TextEditingController _backController;

  @override
  void initState() {
    super.initState();
    _frontController = TextEditingController(text: widget.card.front);
    _backController = TextEditingController(text: widget.card.back);
  }

  @override
  void dispose() {
    widget.card.front = _frontController.text;
    widget.card.back = _backController.text;
    _frontController.dispose();
    _backController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = widget.card.isFlagged
        ? (isDark ? const Color(0xFF4D4000) : const Color(0xFFFFF9C4))
        : (isDark ? AppColors.cDarkSurface : AppColors.cSlate50);

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
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: _buildField(_frontController, isDark, true),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Center(
                      child: _buildField(_backController, isDark, false),
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
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.02),
        border: const Border(
          top: BorderSide(color: Colors.black12, width: 0.5),
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
          _iconAction(Icons.more_vert_rounded, Colors.grey, () {}),
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    bool isDark,
    bool isFront,
  ) {
    return TextField(
      controller: controller,
      maxLines: null,
      onChanged: (val) =>
          isFront ? widget.card.front = val : widget.card.back = val,
      style: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
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
