import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:bivium/models/flashcard.dart';
import 'package:bivium/services/analysis_service.dart';
import 'package:bivium/services/dictionary_service.dart';
import '../../../core/theme.dart';

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
  Map<String, List<AnalyzedWord>>? _groups;
  bool _isAnalyzing = false;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadCache(); // 저장된 데이터 불러오기
  }

  Future<void> _loadCache() async {
    final cached = await AnalysisService().loadFromLocal(
      widget.setInfo.sheetId,
    );
    if (cached != null && mounted) setState(() => _groups = cached);
  }

  Future<void> _handleAnalysis() async {
    if (widget.cards.isEmpty) return;
    setState(() => _isAnalyzing = true);
    try {
      final dict = DictionaryService();
      if (!dict.isInitialized) await dict.init();
      final results = await AnalysisService().analyzeAsync(widget.cards, dict);

      // 결과 영구 저장
      await AnalysisService().saveToLocal(widget.setInfo.sheetId, results);

      if (mounted) {
        setState(() {
          _groups = results;
          _isAnalyzing = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isAnalyzing) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.cBrand600),
      );
    }

    if (_groups == null) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _handleAnalysis,
          icon: const Icon(Icons.bolt),
          label: Text("start_analysis".tr()),

          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.cBrand600,
            foregroundColor: AppColors.cSlate900,
          ),
        ),
      );
    }

    final filteredKeys =
        _groups!.keys.where((k) => k.contains(_searchQuery)).toList()
          ..sort((a, b) {
            final aT = _groups![a]!.any((w) => w.isTypo);
            final bT = _groups![b]!.any((w) => w.isTypo);
            if (aT != bT) return aT ? -1 : 1;
            return _groups![b]!.length.compareTo(_groups![a]!.length);
          });

    return Column(
      children: [
        _buildDashboard(isDark, filteredKeys.length),
        _buildSearchBar(isDark),
        Expanded(
          child: ListView.builder(
            itemCount: filteredKeys.length,
            itemBuilder: (context, i) {
              final k = filteredKeys[i];
              final ws = _groups![k]!;
              final isT = ws.any((w) => w.isTypo);

              return ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: isT ? AppColors.cRed50 : AppColors.cBrand50,
                  child: Text(
                    "${ws.length}",
                    style: TextStyle(
                      fontSize: 12,
                      color: isT ? AppColors.cRed700 : AppColors.cGreen700,
                    ),
                  ),
                ),
                title: Text(
                  k,
                  style: TextStyle(
                    color: isT
                        ? AppColors.cRed700
                        : (isDark ? Colors.white : AppColors.cSlate900),
                  ),
                ),
                children: ws
                    .map(
                      (w) => ListTile(
                        title: Text(w.original),
                        subtitle: Text(
                          "jump_to_card".tr(
                            namedArgs: {'index': (w.cardIndex + 1).toString()},
                          ),
                        ),

                        onTap: () => widget.onCardTap(w.cardIndex),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDashboard(bool isDark, int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: isDark ? AppColors.cDarkSurface : AppColors.cSlate50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "group_count".tr(namedArgs: {'count': count.toString()}),

            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            onPressed: _handleAnalysis,
            icon: Icon(Icons.refresh, color: AppColors.cBrand600),
          ),
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
}
