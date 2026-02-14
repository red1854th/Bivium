import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/flashcard.dart';

List<FlashcardSet> _parseFlashcardSets(String setsJson) {
  final List<dynamic> decoded = jsonDecode(setsJson);
  return decoded.map((item) => FlashcardSet.fromJson(item)).toList();
}

class HomeController extends ChangeNotifier {
  final SharedPreferences prefs;
  List<FlashcardSet> _sets = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = "";

  HomeController({required this.prefs});

  List<FlashcardSet> get sets => _sets;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String get searchQuery => _searchQuery;

  List<FlashcardSet> get filteredSets {
    if (_searchQuery.isEmpty) return _sets;
    return _sets.where((s) {
      return s.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void setSearching(bool searching) {
    _isSearching = searching;
    if (!searching) {
      _searchQuery = "";
    }
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    final String? setsJson = prefs.getString('flashcard_sets');
    if (setsJson != null) {
      final List<FlashcardSet> loadedSets = await compute(
        _parseFlashcardSets,
        setsJson,
      );
      _sets = loadedSets;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveData() async {
    final String encoded = jsonEncode(_sets.map((s) => s.toJson()).toList());
    await prefs.setString('flashcard_sets', encoded);
    await prefs.reload();
  }

  String uniquifyTitle(String title) {
    final existingTitles = _sets.map((s) => s.title).toList();
    if (!existingTitles.contains(title)) return title;
    int counter = 1;
    String newTitle = "$title ($counter)";
    while (existingTitles.contains(newTitle)) {
      counter++;
      newTitle = "$title ($counter)";
    }
    return newTitle;
  }

  void addSet(FlashcardSet set) {
    set.title = uniquifyTitle(set.title);
    _sets.add(set);
    saveData();
    notifyListeners();
  }

  void removeSet(String id) {
    _sets.removeWhere((item) => item.id == id);
    saveData();
    notifyListeners();
  }

  void updateSet(String id, String title, String description) {
    final index = _sets.indexWhere((s) => s.id == id);
    if (index != -1) {
      _sets[index].title = title;
      _sets[index].description = description;
      saveData();
      notifyListeners();
    }
  }

  void reorderSets(int oldIdx, int newIdx) {
    // Reorder logic needs to be careful because we might be reordering filtered sets
    final currentFiltered = filteredSets;
    if (newIdx > oldIdx) newIdx -= 1;

    final item = currentFiltered[oldIdx];
    final actualOldIdx = _sets.indexWhere((element) => element.id == item.id);

    if (actualOldIdx != -1) {
      final movedItem = _sets.removeAt(actualOldIdx);

      if (!_isSearching) {
        _sets.insert(newIdx, movedItem);
      } else {
        if (newIdx < currentFiltered.length) {
          final targetItem = currentFiltered[newIdx];
          final actualNewIdx = _sets.indexWhere(
            (element) => element.id == targetItem.id,
          );
          _sets.insert(actualNewIdx, movedItem);
        } else {
          _sets.add(movedItem);
        }
      }
      saveData();
      notifyListeners();
    }
  }

  void updateLastAccessed(FlashcardSet s) {
    s.lastAccessed = DateTime.now();
    saveData();
    notifyListeners();
  }
}
