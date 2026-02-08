import 'package:bivium/models/flashcard.dart';
import 'package:bivium/services/google_drive_service.dart';
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

class _EditCardPageState extends State<EditCardPage> with WidgetsBindingObserver {
  late PageController _pageController;
  late int _currentPageIndex;
  final Map<int, Flashcard> _editedCards = {}; // Track changes made to cards

  @override
  void initState() {
    super.initState();

    if (widget.cards.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
      _currentPageIndex = 0;
    } else {
      _currentPageIndex = widget.initialCardIndex;
      if (_currentPageIndex < 0 || _currentPageIndex >= widget.cards.length) {
        _currentPageIndex = math.max(
          0,
          math.min(widget.cards.length - 1, _currentPageIndex),
        );
      }
      // Initialize _editedCards with copies of original cards to track changes
      for (int i = 0; i < widget.cards.length; i++) {
        _editedCards[i] = Flashcard(
          key: widget.cards[i].key,
          front: widget.cards[i].front,
          back: widget.cards[i].back,
          isFlagged: widget.cards[i].isFlagged,
          issues: List.from(widget.cards[i].issues),
        );
      }
    }
    _pageController = PageController(initialPage: _currentPageIndex);
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _saveSingleCardChanges(int cardIndex) async {
    final originalCard = widget.cards[cardIndex];
    final editedCard = _editedCards[cardIndex];

    if (editedCard != null &&
        (originalCard.front != editedCard.front ||
            originalCard.back != editedCard.back)) {
      final List<Future<void>> saveFutures = [];

      // Save front content
      saveFutures.add(
        CardEditor._saveStatic(
          widget.setInfo,
          widget.driveService,
          cardIndex,
          widget.setInfo.frontColIdx,
          editedCard.front,
        ),
      );
      // Save back content
      saveFutures.add(
        CardEditor._saveStatic(
          widget.setInfo,
          widget.driveService,
          cardIndex,
          widget.setInfo.backColIdx,
          editedCard.back,
        ),
      );
      await Future.wait(saveFutures);

      // Update the original card in widget.cards to reflect saved changes
      // This prevents re-saving the same changes if user navigates back and forth or on final dispose
      originalCard.front = editedCard.front;
      originalCard.back = editedCard.back;
    }
  }

  // This method will be called when navigating away or app closing
  Future<void> _saveAllChanges() async {
    final List<Future<void>> allSaveFutures = [];

    for (int i = 0; i < widget.cards.length; i++) {
      allSaveFutures.add(
        _saveSingleCardChanges(i),
      ); // Use the new single card save logic
    }
    await Future.wait(allSaveFutures);
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
    if (state == AppLifecycleState.detached) {
      _saveAllChanges(); // Fire and forget
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Cards')),
        body: const Center(
          child: Text('Loading cards or no cards to display.'),
        ),
      );
    }

    return PopScope(
      canPop: false, // Prevent default back button behavior
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        // Updated API
        if (didPop) {
          return;
        }
        // Save all changes when the user attempts to pop the page
        await _saveAllChanges();
        // Pop the current page and return the updated cards to the previous route
        if (!context.mounted) {
          return; // Guard against context use across async gap
        }
        Navigator.of(context).pop(widget.cards);
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Edit Card #${_currentPageIndex + 1}')),
        body: PageView.builder(
          controller: _pageController,
          itemCount: widget.cards.length,
          onPageChanged: (newIndex) async {
            // 1. Dismiss keyboard
            FocusManager.instance.primaryFocus?.unfocus();

            // 2. Save changes of the *previous* card (if the page actually changed)
            final previousIndex =
                _currentPageIndex; // Store old index before updating
            if (previousIndex != newIndex && widget.cards.isNotEmpty) {
              await _saveSingleCardChanges(previousIndex);
            }

            // 3. Update current page index
            setState(() {
              _currentPageIndex = newIndex;
            });
          },
          itemBuilder: (context, index) {
            // Pass the editable card from _editedCards
            final editableCard = _editedCards[index]!;
            return AnimatedBuilder(
              animation: _pageController,
              builder: (context, child) {
                double value = 1.0;
                if (_pageController.position.haveDimensions) {
                  value = (_pageController.page ?? index.toDouble()) - index;
                  value = (1 - (value.abs() * 0.5)).clamp(0.0, 1.0);
                }

                return Transform.rotate(
                  angle:
                      math.pi *
                      ((_pageController.page ?? index.toDouble()) - index) /
                      10,
                  child: CardEditor(
                    key: ValueKey(
                      editableCard.key,
                    ), // Use a unique key for each card
                    card: editableCard, // Pass the editable card
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
    );
  }
}

class CardEditor extends StatefulWidget {
  final Flashcard card; // This card is now directly editable
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

  // Static method to save a single field of a card to Google Sheets
  static Future<void> _saveStatic(
    FlashcardSet setInfo,
    GoogleDriveService driveService,
    int cardIndex,
    int colIdx,
    String value,
  ) async {
    if (setInfo.sheetId.isEmpty) {
      return; // Cannot show SnackBar from static context without context
    }

    if (colIdx < 0 || colIdx > 25) {
      return;
    }

    final row = cardIndex + 2; // +1 for header, +1 for 1-based index
    final range = '${String.fromCharCode(65 + colIdx)}$row';
    try {
      await driveService.updateSpreadsheetCell(setInfo.sheetId, range, value);
    } catch (e) {
      // Cannot show SnackBar from static context without context
    }
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

    // No debounced saving here. Changes are saved on exit of EditCardPage.
    // Update the card object directly for local state
    _frontController.addListener(() {
      widget.card.front = _frontController.text;
    });
    _backController.addListener(() {
      widget.card.back = _backController.text;
    });
  }

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the underlying card object has changed (e.g., after a save and UI rebuild)
    // update the controllers to reflect the new data.
    if (widget.card.front != oldWidget.card.front) {
      _frontController.text = widget.card.front;
    }
    if (widget.card.back != oldWidget.card.back) {
      _backController.text = widget.card.back;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTextStyle = Theme.of(context).textTheme.titleMedium;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.centerRight,
            children: [
              TextField(
                controller: _frontController,
                decoration: const InputDecoration(
                  labelText: 'Source',
                  border: OutlineInputBorder(),
                ),
                style: effectiveTextStyle,
                maxLines: null, // Allow unlimited lines
                keyboardType: TextInputType.multiline,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.centerRight,
            children: [
              TextField(
                controller: _backController,
                decoration: const InputDecoration(
                  labelText: 'Target',
                  border: OutlineInputBorder(),
                ),
                style: effectiveTextStyle,
                maxLines: null, // Allow unlimited lines
                keyboardType: TextInputType.multiline,
              ),
            ],
          ),
        ],
      ), // Close Column
    ); // Close Padding
  }
}
