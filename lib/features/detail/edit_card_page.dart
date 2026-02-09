import 'package:bivium/models/flashcard.dart';
import 'package:bivium/services/google_drive_service.dart';
import 'package:bivium/features/detail/remark_page.dart';
import 'package:flutter/material.dart';
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
    final Color contrastBgColor = isDark
        ? Colors.grey[200]!
        : Colors.grey[900]!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _saveAllChanges();
        if (context.mounted) Navigator.of(context).pop(widget.cards);
      },
      child: Scaffold(
        backgroundColor: contrastBgColor,
        appBar: AppBar(
          title: Text(
            'Edit Card #${_currentPageIndex + 1}',
            style: TextStyle(color: isDark ? Colors.black87 : Colors.white),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(
            color: isDark ? Colors.black87 : Colors.white,
          ),
          centerTitle: true,
        ),
        body: PageView.builder(
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
                double angle = (page - index) * (math.pi / 25);
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
        bottomNavigationBar: _buildYoutubeStyleBar(isDark),
      ),
    );
  }

  Widget _buildYoutubeStyleBar(bool isDark) {
    final Color barColor = isDark ? Colors.grey[200]! : Colors.grey[900]!;
    return Container(
      decoration: BoxDecoration(
        color: barColor,
        border: Border(
          top: BorderSide(
            color: Colors.black.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bottomActionItem(
                Icons.history_edu_rounded,
                'Remark',
                isDark,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RemarkPage(
                        service: widget.driveService,
                        spreadsheetId: widget.setInfo.sheetId,
                        cardIndex: _currentPageIndex,
                        columnIdx: widget.setInfo.remarkColIdx,
                        initialRemark:
                            _editedCards[_currentPageIndex]?.remark ?? '',
                      ),
                    ),
                  );
                },
              ),
              _bottomActionItem(Icons.flag_outlined, 'Flag', isDark, () {}),
              _bottomActionItem(
                Icons.ios_share_rounded,
                'Share',
                isDark,
                () {},
              ),
              _bottomActionItem(Icons.more_vert_rounded, 'More', isDark, () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomActionItem(
    IconData icon,
    String label,
    bool isDark,
    VoidCallback onTap,
  ) {
    final Color itemColor = isDark ? Colors.black87 : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: itemColor),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: itemColor)),
          ],
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
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    _buildLabel('Source'),
                    Center(child: _buildField(_frontController)),
                  ],
                ),
              ),
              Divider(
                height: 1,
                thickness: 1,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
              ),
              Expanded(
                child: Stack(
                  children: [
                    _buildLabel('Target'),
                    Center(child: _buildField(_backController)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Align(
      alignment: Alignment.topLeft,
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.6),
          fontSize: 13,
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller) {
    return TextField(
      controller: controller,
      maxLines: null,
      textAlign: TextAlign.left,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }
}
