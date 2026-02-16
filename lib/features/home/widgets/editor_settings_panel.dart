import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bivium/core/theme.dart';
import 'package:bivium/models/flashcard.dart';

class EditorSettings {
  final double fontSize;
  final double lineHeight;
  final String fontFamily;

  EditorSettings({
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
  });
}

class EditorSettingsPanel extends StatefulWidget {
  final bool isVisible;
  final EditorSettings currentSettings;
  final Function(EditorSettings) onSettingsChanged;
  final VoidCallback onClose;
  final Flashcard card;
  final int cardIndex;

  const EditorSettingsPanel({
    super.key,
    required this.isVisible,
    required this.currentSettings,
    required this.onSettingsChanged,
    required this.onClose,
    required this.card,
    required this.cardIndex,
  });

  @override
  State<EditorSettingsPanel> createState() => _EditorSettingsPanelState();
}

class _EditorSettingsPanelState extends State<EditorSettingsPanel> {
  late double _fontSize;
  late double _lineHeight;
  late String _fontFamily;

  @override
  void initState() {
    super.initState();
    _resetLocalStates();
  }

  @override
  void didUpdateWidget(EditorSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentSettings != widget.currentSettings) {
      _resetLocalStates();
    }
  }

  void _resetLocalStates() {
    _fontSize = widget.currentSettings.fontSize;
    _lineHeight = widget.currentSettings.lineHeight;
    _fontFamily = widget.currentSettings.fontFamily;
  }

  void _update() async {
    final settings = EditorSettings(
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      fontFamily: _fontFamily,
    );
    widget.onSettingsChanged(settings);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('editor_font_size', _fontSize);
    await prefs.setDouble('editor_line_height', _lineHeight);
    await prefs.setString('editor_font_family', _fontFamily);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double panelWidth = MediaQuery.of(context).size.width * 0.65;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutQuart,
      right: widget.isVisible ? 0 : -panelWidth,
      top: 0,
      bottom: 0,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          if (details.delta.dx > 8) widget.onClose();
        },
        child: Container(
          width: panelWidth,
          decoration: BoxDecoration(
            // AppColors에 정의된 다크모드 서피스 컬러 반영
            color: isDark ? AppColors.cDarkSurface : Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              bottomLeft: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
                blurRadius: 25,
                offset: const Offset(-5, 0),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCardInfoHeader(isDark),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: isDark ? AppColors.cDarkBorder : AppColors.cBorder,
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "view_settings".tr(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.cSlate400 : AppColors.cSlate500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildMenuTile(
                        icon: Icons.font_download_outlined,
                        value: _fontFamily,
                        onTap: () => _showFontPicker(context),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildSliderTile(
                        Icons.format_size,
                        "font_size".tr(),
                        _fontSize,
                        14,
                        40,
                        (v) {
                          setState(() => _fontSize = v);
                          _update();
                        },
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildSliderTile(
                        Icons.format_line_spacing,
                        "line_height".tr(),
                        _lineHeight,
                        1.0,
                        2.2,
                        (v) {
                          setState(() => _lineHeight = v);
                          _update();
                        },
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardInfoHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cBrand600.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "#${widget.cardIndex + 1}",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cBrand600,
                  ),
                ),
              ),
              if (widget.card.key.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  widget.card.key,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.cSlate500 : AppColors.cSlate400,
                  ),
                ),
              ],
              const Spacer(),
              if (widget.card.isFlagged)
                const Icon(Icons.flag_rounded, color: Colors.orange, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.card.front.isEmpty
                ? "No Content"
                : widget.card.front.split('\n').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.cSlate100 : AppColors.cSlate800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.card.remark.isEmpty ? "No remarks" : widget.card.remark,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.cSlate500 : AppColors.cSlate400,
            ),
          ),
        ],
      ),
    );
  }

  void _showFontPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.cDarkSurface
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final fonts = ['Pretendard', 'System', 'Serif', 'Monospace'];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: ListView(
            shrinkWrap: true,
            children: fonts
                .map(
                  (font) => ListTile(
                    title: Text(
                      font,
                      style: TextStyle(
                        fontFamily: font == 'System' ? null : font,
                      ),
                    ),
                    trailing: _fontFamily == font
                        ? const Icon(Icons.check, color: AppColors.cBrand600)
                        : null,
                    onTap: () {
                      setState(() => _fontFamily = font);
                      _update();
                      Navigator.pop(context);
                    },
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String value,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isDark ? AppColors.cSlate400 : Colors.grey,
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.cSlate200 : AppColors.cSlate800,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: isDark ? AppColors.cSlate600 : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderTile(
    IconData icon,
    String label,
    double val,
    double min,
    double max,
    Function(double) onChanged, {
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: isDark ? AppColors.cSlate500 : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.cSlate400 : Colors.grey,
                ),
              ),
              const Spacer(),
              Text(
                val.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.cBrand600 : AppColors.cSlate800,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: AppColors.cBrand600,
              inactiveTrackColor: isDark
                  ? AppColors.cDarkBorder
                  : Colors.black12,
              thumbColor: AppColors.cBrand600,
            ),
            child: Slider(value: val, min: min, max: max, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}
