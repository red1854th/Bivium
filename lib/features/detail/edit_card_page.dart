import 'package:bivium/models/flashcard.dart';
import 'package:bivium/services/google_drive_service.dart';
import 'package:bivium/features/detail/remark_page.dart';
import 'package:bivium/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class EditCardPage extends StatefulWidget {
  final List<Flashcard> cards;
  final int initialCardIndex;
  final FlashcardSet setInfo;
  final GoogleDriveService driveService;

  const EditCardPage({
    super.key,
    required this.cards,
    required this.initialCardIndex,
    required this.setInfo,
    required this.driveService,
  });

  @override
  State<EditCardPage> createState() => _EditCardPageState();
}

class _EditCardPageState extends State<EditCardPage> {
  late PageController _pageController;
  late int _currentPageIndex;

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.initialCardIndex.clamp(
      0,
      widget.cards.length - 1,
    );
    _pageController = PageController(initialPage: _currentPageIndex);
  }

  /// 서버 동기화 함수 (비동기 실행)
  void _saveChanges(int index) {
    if (index < 0 || index >= widget.cards.length) return;

    final card = widget.cards[index];
    // 가독성을 위해 비동기 처리를 분리하여 실행
    widget.driveService
        .updateFlashcard(
          spreadsheetId: widget.setInfo.sheetId,
          cardIndex: index,
          setInfo: widget.setInfo,
          card: card,
        )
        .catchError((e) {
          debugPrint('백그라운드 저장 실패: $e');
        });
  }

  /// 즉시 종료 처리
  void _handlePop() {
    FocusManager.instance.primaryFocus?.unfocus();

    // 저장을 기다리지 않고 즉시 실행 (Fire-and-forget)
    _saveChanges(_currentPageIndex);

    // 대기 없이 즉시 화면 이탈
    if (mounted) {
      Navigator.of(context).pop(widget.cards);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? AppColors.cDarkBg : AppColors.cBg;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handlePop();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          toolbarHeight: 30,
          leadingWidth: 48,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
          ),
          leading: Transform.translate(
            offset: const Offset(4, -6),
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _handlePop,
            ),
          ),
          title: Text(
            '${_currentPageIndex + 1}/${widget.cards.length}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.cSlate200 : AppColors.cSlate800,
            ),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          centerTitle: true,
        ),
        body: SafeArea(
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.cards.length,
            onPageChanged: (idx) {
              int prevIdx = _currentPageIndex;
              _saveChanges(prevIdx); // 이전 페이지 변경분 백그라운드 저장
              if (mounted) setState(() => _currentPageIndex = idx);
            },
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double page = _pageController.hasClients
                      ? (_pageController.page ?? index.toDouble())
                      : index.toDouble();
                  double angle = (page - index) * (math.pi / 35);
                  return Transform.rotate(
                    angle: angle,
                    child: CardEditor(
                      key: ValueKey('editor_${widget.cards[index].key}_$index'),
                      card: widget.cards[index],
                      cardIndex: index,
                      setInfo: widget.setInfo,
                      driveService: widget.driveService,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

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
    // 텍스트 필드 최종본 반영
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
          Container(
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
                  () => setState(
                    () => widget.card.isFlagged = !widget.card.isFlagged,
                  ),
                ),
                _iconAction(Icons.ios_share_rounded, Colors.grey, () {}),
                _iconAction(Icons.more_vert_rounded, Colors.grey, () {}),
              ],
            ),
          ),
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
      onChanged: (val) {
        if (isFront) {
          widget.card.front = val;
        } else {
          widget.card.back = val;
        }
      },
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
