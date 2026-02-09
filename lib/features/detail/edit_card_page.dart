import 'package:bivium/models/flashcard.dart';
import 'package:bivium/services/google_drive_service.dart';
import 'package:bivium/features/detail/remark_page.dart';
import 'package:bivium/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';

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

class _EditCardPageState extends State<EditCardPage>
    with WidgetsBindingObserver {
  late PageController _pageController;
  late int _currentPageIndex;
  final Map<int, Flashcard> _editedCards = {};

  @override
  void initState() {
    super.initState();
    if (widget.cards.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      _currentPageIndex = 0;
    } else {
      _currentPageIndex = widget.initialCardIndex.clamp(
        0,
        widget.cards.length - 1,
      );
      for (int i = 0; i < widget.cards.length; i++) {
        _editedCards[i] = Flashcard(
          key: widget.cards[i].key,
          front: widget.cards[i].front,
          back: widget.cards[i].back,
          remark: widget.cards[i].remark,
          isFlagged: widget.cards[i].isFlagged,
          issues: List.from(widget.cards[i].issues),
        );
      }
    }
    _pageController = PageController(
      initialPage: _currentPageIndex,
      viewportFraction: 1.0,
    );
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _saveSingleCardChanges(int cardIndex) async {
    final original = widget.cards[cardIndex];
    final edited = _editedCards[cardIndex];
    if (edited != null &&
        (original.front != edited.front || original.back != edited.back)) {
      await Future.wait([
        CardEditor._saveStatic(
          widget.setInfo,
          widget.driveService,
          cardIndex,
          widget.setInfo.frontColIdx,
          edited.front,
        ),
        CardEditor._saveStatic(
          widget.setInfo,
          widget.driveService,
          cardIndex,
          widget.setInfo.backColIdx,
          edited.back,
        ),
      ]);
      original.front = edited.front;
      original.back = edited.back;
    }
  }

  Future<void> _saveAllChanges() async {
    final List<Future<void>> futures = [];
    for (int i = 0; i < widget.cards.length; i++) {
      futures.add(_saveSingleCardChanges(i));
    }
    await Future.wait(futures);
  }

  @override
  void dispose() {
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _saveAllChanges();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) _saveAllChanges();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? AppColors.cDarkBg : AppColors.cBg;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _saveAllChanges();
        if (context.mounted) Navigator.of(context).pop(widget.cards);
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
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
          leading: Transform.translate(
            offset: const Offset(4, -6),
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              iconSize: 25,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onPressed: () {
                _saveAllChanges();
                Navigator.of(context).pop(widget.cards);
              },
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
        // SafeArea 적용: 하단 내비게이션 바 영역 보호
        body: SafeArea(
          bottom: true,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.cards.length,
            onPageChanged: (idx) async {
              FocusManager.instance.primaryFocus?.unfocus();
              if (_currentPageIndex != idx) {
                await _saveSingleCardChanges(_currentPageIndex);
              }
              setState(() => _currentPageIndex = idx);
            },
            itemBuilder: (context, index) {
              final editableCard = _editedCards[index]!;
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
                      key: ValueKey(editableCard.key),
                      card: editableCard,
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

  static Future<void> _saveStatic(
    FlashcardSet set,
    GoogleDriveService svc,
    int idx,
    int col,
    String val,
  ) async {
    if (set.sheetId.isEmpty || col < 0) return;
    final range = '${String.fromCharCode(65 + col)}${idx + 2}';
    try {
      await svc.updateSpreadsheetCell(set.sheetId, range, val);
    } catch (_) {}
  }
}

class _CardEditorState extends State<CardEditor> {
  late TextEditingController _frontController;
  late TextEditingController _backController;

  @override
  void initState() {
    super.initState();
    _frontController = TextEditingController(text: widget.card.front);
    _backController = TextEditingController(text: widget.card.back);
    _frontController.addListener(
      () => widget.card.front = _frontController.text,
    );
    _backController.addListener(() => widget.card.back = _backController.text);
  }

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardBg = isDark ? AppColors.cDarkSurface : AppColors.cSlate50;
    final Color borderColor = isDark
        ? AppColors.cDarkBorder
        : AppColors.cSlate200;
    final Color itemColor = isDark ? AppColors.cSlate400 : AppColors.cSlate600;

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 5, 10, 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Center(child: _buildField(_frontController, isDark)),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: borderColor.withValues(alpha: 0.5),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Center(child: _buildField(_backController, isDark)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 40,
              padding: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.02),
                border: Border(
                  top: BorderSide(
                    color: borderColor.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _iconOnlyActionItem(Icons.history_edu_rounded, itemColor, () {
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
                  _iconOnlyActionItem(Icons.flag_outlined, itemColor, () {}),
                  _iconOnlyActionItem(
                    Icons.ios_share_rounded,
                    itemColor,
                    () {},
                  ),
                  _iconOnlyActionItem(
                    Icons.more_vert_rounded,
                    itemColor,
                    () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, bool isDark) {
    return TextField(
      controller: controller,
      maxLines: null,
      textAlign: TextAlign.left,
      style: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.cSlate100 : AppColors.cSlate900,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 8),
      ),
    );
  }

  Widget _iconOnlyActionItem(IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Center(child: Icon(icon, size: 20, color: color)),
      ),
    );
  }
}
