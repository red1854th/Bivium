import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:bivium/models/flashcard.dart';
import 'package:bivium/services/analysis_service.dart';
import '../../../core/theme.dart';
import 'package:bivium/widgets/card_list_common.dart';

class StatisticsTab extends StatefulWidget {
  final List<Flashcard> cards;
  final FlashcardSet setInfo;
  final Function(int) onCardTap;

  const StatisticsTab({
    super.key,
    required this.cards,
    required this.setInfo,
    required this.onCardTap,
  });

  @override
  State<StatisticsTab> createState() => _StatisticsTabState();
}

class _StatisticsTabState extends State<StatisticsTab> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildMenuCard(
            isDark,
            icon: Icons.spellcheck_rounded,
            title: "typo_analysis".tr(),
            subtitle: "find_potential_typos_desc".tr(),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => _TypoAnalysisPage(
                    cards: widget.cards,
                    onCardTap: widget.onCardTap,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildMenuCard(
            isDark,
            icon: Icons.difference_rounded,
            title: "similar_analysis".tr(),
            subtitle: "group_similar_cards_desc".tr(),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => _SimilarAnalysisPage(
                    cards: widget.cards,
                    onCardTap: widget.onCardTap,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cDarkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.cDarkBorder : AppColors.cSlate200,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cBrand600.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.cBrand600, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.cSlate900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.cSlate400 : AppColors.cSlate500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? AppColors.cSlate600 : AppColors.cSlate300,
            ),
          ],
        ),
      ),
    );
  }
}

class _TypoAnalysisPage extends StatefulWidget {
  final List<Flashcard> cards;
  final Function(int) onCardTap;

  const _TypoAnalysisPage({required this.cards, required this.onCardTap});

  @override
  State<_TypoAnalysisPage> createState() => _TypoAnalysisPageState();
}

class _TypoAnalysisPageState extends State<_TypoAnalysisPage> {
  Map<String, List<AnalyzedWord>>? _groups;
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  Future<void> _startAnalysis() async {
    try {
      final results = await AnalysisService().analyzeAsync(widget.cards);
      if (mounted) {
        setState(() {
          _groups = results;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: ThemeService.getBackgroundColor(isDark),
      appBar: AppBar(
        title: Text("typo_analysis".tr()),
        backgroundColor: ThemeService.getBackgroundColor(isDark),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchBar(isDark),
                Expanded(child: _buildTypoList(isDark)),
              ],
            ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: "search".tr(),
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: isDark ? AppColors.cDarkSurface : AppColors.cSlate100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildTypoList(bool isDark) {
    if (_groups == null || _groups!.isEmpty) {
      return Center(child: Text("no_data".tr()));
    }

    final filteredKeys =
        _groups!.keys.where((k) {
          if (_searchQuery.isNotEmpty) return k.contains(_searchQuery);
          return true;
        }).toList()..sort((a, b) {
          final aScore =
              _groups![a]!.fold<double>(0, (prev, e) => prev + e.typoScore) /
              _groups![a]!.length;
          final bScore =
              _groups![b]!.fold<double>(0, (prev, e) => prev + e.typoScore) /
              _groups![b]!.length;
          if ((bScore - aScore).abs() > 0.01) return bScore.compareTo(aScore);
          return _groups![b]!.length.compareTo(_groups![a]!.length);
        });

    return ListView.builder(
      itemCount: filteredKeys.length,
      itemBuilder: (context, i) {
        final k = filteredKeys[i];
        final ws = _groups![k]!;
        final avgScore =
            ws.fold<double>(0, (p, e) => p + e.typoScore) / ws.length;
        final isLikelyTypo = avgScore > 40;

        return ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: isLikelyTypo
                ? AppColors.cRed50
                : AppColors.cBrand50,
            child: Text(
              "${ws.length}",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isLikelyTypo ? AppColors.cRed700 : AppColors.cGreen700,
              ),
            ),
          ),
          title: Text(
            k,
            style: TextStyle(
              fontWeight: isLikelyTypo ? FontWeight.bold : FontWeight.normal,
              color: isLikelyTypo
                  ? AppColors.cRed700
                  : (isDark ? Colors.white : AppColors.cSlate900),
            ),
          ),
          trailing: Text(
            "${avgScore.toStringAsFixed(1)}%",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: avgScore > 40 ? AppColors.cRed700 : AppColors.cSlate400,
            ),
          ),
          children: ws
              .map(
                (w) => ListTile(
                  dense: true,
                  title: Text(w.original),
                  subtitle: Text(
                    "jump_to_card".tr(
                      namedArgs: {'index': (w.cardIndex + 1).toString()},
                    ),
                  ),
                  trailing: Text("${w.typoScore.toStringAsFixed(1)}%"),
                  onTap: () {
                    SearchManager().update(w.original, true);
                    widget.onCardTap(-1);
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SimilarAnalysisPage extends StatefulWidget {
  final List<Flashcard> cards;
  final Function(int) onCardTap;

  const _SimilarAnalysisPage({required this.cards, required this.onCardTap});

  @override
  State<_SimilarAnalysisPage> createState() => _SimilarAnalysisPageState();
}

class _SimilarAnalysisPageState extends State<_SimilarAnalysisPage> {
  List<SimilarGroup>? _similarGroups;
  List<SimilarGroup>? _searchSimilarityGroups;
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = "";
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  Future<void> _startAnalysis() async {
    try {
      final results = await AnalysisService().findSimilarCardsAsync(
        widget.cards,
      );
      if (mounted) {
        setState(() {
          _similarGroups = results;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: ThemeService.getBackgroundColor(isDark),
      appBar: AppBar(
        title: Text("similar_analysis".tr()),
        backgroundColor: ThemeService.getBackgroundColor(isDark),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchBar(isDark),
                Expanded(child: _buildSimilarList(isDark)),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() {
          _searchQuery = "";
          _searchSimilarityGroups = null;
          _isSearching = false;
        });
        return;
      }

      setState(() {
        _searchQuery = query;
        _isSearching = true;
      });

      try {
        final results = await AnalysisService().findSimilarByQueryAsync(
          cards: widget.cards,
          query: query,
        );
        if (mounted) {
          setState(() {
            _searchSimilarityGroups = results;
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: "search_similar_hint".tr(),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _isSearching
              ? Container(
                  width: 20,
                  height: 20,
                  padding: const EdgeInsets.all(12),
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          filled: true,
          fillColor: isDark ? AppColors.cDarkSurface : AppColors.cSlate100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildSimilarList(bool isDark) {
    final bool isSearchActive = _searchQuery.isNotEmpty;
    final List<SimilarGroup>? sourceGroups = isSearchActive
        ? _searchSimilarityGroups
        : _similarGroups;

    if (sourceGroups == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (sourceGroups.isEmpty) {
      return Center(
        child: Text(
          isSearchActive ? "no_search_results".tr() : "no_similar_cards".tr(),
        ),
      );
    }

    final filtered =
        sourceGroups; // Already filtered/grouped by task in query mode

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final g = filtered[i];
        return ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.cAmber50,
            child: Text(
              "${g.cards.length}",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.cAmber700,
              ),
            ),
          ),
          title: Text(
            g.commonPart,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.cBrand700,
            ),
          ),
          children: g.cards
              .map(
                (c) => ListTile(
                  dense: true,
                  title: _buildHighlightedText(c.front, g.commonPart, isDark),
                  subtitle: _buildHighlightedText(c.back, g.commonPart, isDark),
                  onTap: () {
                    SearchManager().update(c.front, true);
                    widget.onCardTap(-1);
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildHighlightedText(String text, String highlight, bool isDark) {
    if (highlight.isEmpty) {
      return Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      );
    }

    final String textLower = text.toLowerCase();
    final String highlightLower = highlight.toLowerCase();

    if (!textLower.contains(highlightLower)) {
      return Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      );
    }

    final List<TextSpan> spans = [];
    int start = 0;
    int index;

    while ((index = textLower.indexOf(highlightLower, start)) != -1) {
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + highlight.length),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.cBrand600,
          ),
        ),
      );
      start = index + highlight.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : AppColors.cSlate900,
        ),
        children: spans,
      ),
    );
  }
}
