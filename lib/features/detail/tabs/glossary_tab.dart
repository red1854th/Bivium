import 'package:bivium/models/flashcard.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../home/setting_page.dart';

import 'package:easy_localization/easy_localization.dart';
import '../../../core/theme.dart';
import '../../../models/substitution.dart';
import '../../../models/glossary_item.dart';

// GlossaryEntry is essentially a Substitution. We'll transition to Substitution.
typedef GlossaryEntry = Substitution;

class GlossaryTab extends StatefulWidget {
  final List<Flashcard> cards;
  final FlashcardSet setInfo;
  final SharedPreferences prefs;
  final VoidCallback? onUpdate;

  const GlossaryTab({
    super.key,
    required this.cards,
    required this.setInfo,
    required this.prefs,
    this.onUpdate,
  });

  @override
  // ignore: library_private_types_in_public_api
  _GlossaryTabState createState() => _GlossaryTabState();
}

class _GlossaryTabState extends State<GlossaryTab> {
  List<Substitution> get _substitutions {
    final raw = widget.setInfo.metadata?['substitutions'];
    if (raw == null) return [];
    return Substitution.deserializeList(raw);
  }

  void _updateSubstitutions(List<Substitution> subs) {
    setState(() {
      final metadata = Map<String, String>.from(widget.setInfo.metadata ?? {});
      metadata['substitutions'] = Substitution.serializeList(subs);
      widget.setInfo.metadata = metadata;
    });
    widget.onUpdate?.call();
  }

  String get _memo {
    return widget.setInfo.metadata?['memo'] ?? '';
  }

  void _updateMemo(String text) {
    setState(() {
      final metadata = Map<String, String>.from(widget.setInfo.metadata ?? {});
      metadata['memo'] = text;
      widget.setInfo.metadata = metadata;
    });
    widget.onUpdate?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildMenuCard(
            context,
            isDark,
            icon: Icons.book_outlined,
            title: 'glossary_title'.tr(),
            subtitle: 'glossary_desc'.tr(),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => _ProjectGlossaryPage(
                    setInfo: widget.setInfo,
                    onUpdate: widget.onUpdate,
                    prefs: widget.prefs,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildMenuCard(
            context,
            isDark,
            icon: Icons.note_alt_outlined,
            title: 'project_memo_title'.tr(),
            subtitle: 'project_memo_desc'.tr(),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      _ProjectMemoPage(initialText: _memo, onSave: _updateMemo),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildMenuCard(
            context,
            isDark,
            icon: Icons.find_replace,
            title: 'text_substitution_settings'.tr(),
            subtitle: 'text_substitution_desc'.tr(),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubstitutionManagementPage(
                    prefs: widget.prefs,
                    isGlobal: false,
                    projectSubstitutions: _substitutions,
                    onSaveProject: _updateSubstitutions,
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
    BuildContext context,
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
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
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

class _ProjectMemoPage extends StatefulWidget {
  final String initialText;
  final Function(String) onSave;

  const _ProjectMemoPage({required this.initialText, required this.onSave});

  @override
  State<_ProjectMemoPage> createState() => _ProjectMemoPageState();
}

class _ProjectMemoPageState extends State<_ProjectMemoPage> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: ThemeService.getBackgroundColor(isDark),
      appBar: AppBar(
        title: Text('project_memo_title'.tr()),
        backgroundColor: ThemeService.getBackgroundColor(isDark),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(
            hintText: 'enter_memo_hint'.tr(),
            border: InputBorder.none,
          ),
          onChanged: (val) => widget.onSave(val),
        ),
      ),
    );
  }
}

class _ProjectGlossaryPage extends StatefulWidget {
  final FlashcardSet setInfo;
  final VoidCallback? onUpdate;
  final SharedPreferences prefs;

  const _ProjectGlossaryPage({
    required this.setInfo,
    this.onUpdate,
    required this.prefs,
  });

  @override
  State<_ProjectGlossaryPage> createState() => _ProjectGlossaryPageState();
}

class _ProjectGlossaryPageState extends State<_ProjectGlossaryPage> {
  List<GlossaryItem> get _glossary {
    final raw = widget.setInfo.metadata?['glossary'] ?? '[]';
    return GlossaryItem.deserializeList(raw);
  }

  void _updateGlossary(List<GlossaryItem> items) {
    setState(() {
      final metadata = Map<String, String>.from(widget.setInfo.metadata ?? {});
      metadata['glossary'] = GlossaryItem.serializeList(items);
      widget.setInfo.metadata = metadata;
    });
    widget.onUpdate?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GlossaryManagementPage(
      prefs: widget.prefs,
      isGlobal: false,
      projectGlossary: _glossary,
      onSaveProject: _updateGlossary,
    );
  }
}
