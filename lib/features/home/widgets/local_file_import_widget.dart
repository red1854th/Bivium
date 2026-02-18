import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../../core/theme.dart';
import '../../../models/flashcard.dart';
import '../../../services/google_drive_service.dart';

// 엄격한 복원을 위한 별도 저장 구조체
class FileStructureMetadata {
  final String filePrefix;
  final String regexPrefix;
  final String sep1;
  final String sep2;
  final String regexSuffix;
  final String fileSuffix;
  final String finalRegex;

  FileStructureMetadata({
    required this.filePrefix,
    required this.regexPrefix,
    required this.sep1,
    required this.sep2,
    required this.regexSuffix,
    required this.fileSuffix,
    required this.finalRegex,
  });

  Map<String, dynamic> toJson() => {
    'file_prefix': filePrefix,
    'regex_prefix': regexPrefix,
    'sep1': sep1,
    'sep2': sep2,
    'regex_suffix': regexSuffix,
    'file_suffix': fileSuffix,
    'final_regex': finalRegex,
  };
}

class LocalFileImportWidget extends StatefulWidget {
  final GoogleDriveService service;
  final Function(FlashcardSet) onAdd;

  const LocalFileImportWidget({
    super.key,
    required this.service,
    required this.onAdd,
  });

  @override
  State<LocalFileImportWidget> createState() => _LocalFileImportWidgetState();
}

class _LocalFileImportWidgetState extends State<LocalFileImportWidget> {
  String? _fileContent;
  String? _fileName;
  final TextEditingController _sampleController = TextEditingController();

  String _selectedKey = "";
  String _selectedSource = "";
  String _selectedTarget = "";

  // 엄격한 추출 구성 요소
  String _filePrefix = "";
  String _regexPrefix = "";
  String _sep1 = "";
  String _sep2 = "";
  String _regexSuffix = "";
  String _fileSuffix = "";
  String _finalRegex = "";

  List<Map<String, String>> _extractedData = [];
  bool _isUploading = false;
  bool _isDragging = false;

  void _processFileData(String name, List<int> bytes) {
    try {
      final content = utf8.decode(bytes);
      setState(() {
        _fileName = name;
        _fileContent = content;
        _sampleController.text = content.substring(
          0,
          min(content.length, 50000),
        );
        _clearSelections();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('file_decode_error'.tr())));
      }
    }
  }

  void _clearSelections() {
    setState(() {
      _selectedKey = "";
      _selectedSource = "";
      _selectedTarget = "";
      _filePrefix = "";
      _regexPrefix = "";
      _sep1 = "";
      _sep2 = "";
      _regexSuffix = "";
      _fileSuffix = "";
      _finalRegex = "";
      _extractedData.clear();
    });
  }

  void _inferAndExtract() {
    if (_fileContent == null || _selectedSource.isEmpty) return;
    final String c = _fileContent!;

    try {
      // 1. 구분자(Separator) 및 프리픽스 추출
      if (_selectedKey.isNotEmpty) {
        final mPre = RegExp(
          '(.*?)${RegExp.escape(_selectedKey)}',
          dotAll: true,
        ).firstMatch(c);
        _regexPrefix = RegExp.escape(mPre?.group(1)?.split('\n').last ?? "");

        final m1 = RegExp(
          '${RegExp.escape(_selectedKey)}(.*?)${RegExp.escape(_selectedSource)}',
          dotAll: true,
        ).firstMatch(c);
        _sep1 = RegExp.escape(m1?.group(1) ?? "");
      }

      if (_selectedTarget.isNotEmpty) {
        final m2 = RegExp(
          '${RegExp.escape(_selectedSource)}(.*?)${RegExp.escape(_selectedTarget)}',
          dotAll: true,
        ).firstMatch(c);
        _sep2 = RegExp.escape(m2?.group(1) ?? "");

        final mSuf = RegExp(
          '${RegExp.escape(_selectedTarget)}(.*?)(?=\\n|\\r|\$)',
          dotAll: true,
        ).firstMatch(c);
        _regexSuffix = RegExp.escape(mSuf?.group(1) ?? "");
      } else {
        final mSuf = RegExp(
          '${RegExp.escape(_selectedSource)}(.*?)(?=\\n|\\r|\$)',
          dotAll: true,
        ).firstMatch(c);
        _regexSuffix = RegExp.escape(mSuf?.group(1) ?? "");
      }

      // 2. 정규식 조립
      String pattern = "";
      if (_selectedKey.isNotEmpty && _selectedTarget.isNotEmpty) {
        pattern = '$_regexPrefix(.*?)$_sep1(.*?)$_sep2(.*?)$_regexSuffix';
      } else if (_selectedKey.isNotEmpty) {
        pattern = '$_regexPrefix(.*?)$_sep1(.*?)$_regexSuffix';
      } else {
        pattern = '$_regexPrefix(.*?)$_regexSuffix';
      }

      final regExp = RegExp(pattern, multiLine: true);
      final matches = regExp.allMatches(c).toList();

      setState(() {
        _finalRegex = pattern;
        if (matches.isNotEmpty) {
          _filePrefix = c.substring(0, matches.first.start);
          _fileSuffix = c.substring(matches.last.end);
          _extractedData = matches.map((m) {
            int i = 1;
            return {
              'key': _selectedKey.isNotEmpty ? (m.group(i++) ?? "") : "",
              'source': m.group(i++) ?? "",
              'target': _selectedTarget.isNotEmpty ? (m.group(i++) ?? "") : "",
            };
          }).toList();
        }
      });
    } catch (e) {
      debugPrint("Structure Logic Error: $e");
    }
  }

  void _assignSelection(int type) {
    final sel = _sampleController.selection;
    if (sel.isCollapsed) return;
    final txt = _sampleController.text.substring(sel.start, sel.end);
    setState(() {
      if (type == 0) {
        _selectedKey = txt;
      } else if (type == 1) {
        _selectedSource = txt;
      } else {
        _selectedTarget = txt;
      }
    });
    _inferAndExtract();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('import_file'.tr()),
        actions: [
          if (_fileContent != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _clearSelections,
            ),
        ],
      ),
      body: DropTarget(
        onDragDone: (d) async => _processFileData(
          d.files.first.name,
          await d.files.first.readAsBytes(),
        ),
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        child: Container(
          color: _isDragging ? AppColors.cBrand600.withAlpha(20) : null,
          padding: const EdgeInsets.all(16),
          child: _fileContent == null
              ? _buildPlaceholder()
              : _buildEditorLayout(),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.upload_file, size: 64, color: AppColors.cSlate400),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _pickFile, child: Text('browse_files'.tr())),
      ],
    ),
  );

  Widget _buildEditorLayout() => Column(
    children: [
      _buildSelectionInfo(),
      const Divider(height: 24),
      Expanded(
        child: Row(
          children: [
            Expanded(flex: 1, child: _buildSourceEditor()),
            const VerticalDivider(width: 32),
            Expanded(flex: 1, child: _buildPreviewList()),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _buildUploadButton(),
    ],
  );

  Widget _buildSelectionInfo() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.cBrand600.withAlpha(10),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _infoItem("Key", _selectedKey),
        _infoItem("Source", _selectedSource),
        _infoItem("Target", _selectedTarget),
      ],
    ),
  );

  Widget _infoItem(String label, String value) => Column(
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
      Text(
        value.isEmpty ? "-" : value,
        style: const TextStyle(fontSize: 12, color: AppColors.cBrand700),
      ),
    ],
  );

  Widget _buildSourceEditor() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'select_sample_text'.tr(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: TextField(
          controller: _sampleController,
          maxLines: null,
          expands: true,
          readOnly: true,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          decoration: const InputDecoration(
            filled: true,
            border: OutlineInputBorder(),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: _selBtn("Key", 0)),
          const SizedBox(width: 4),
          Expanded(child: _selBtn("Source*", 1)),
          const SizedBox(width: 4),
          Expanded(child: _selBtn("Target", 2)),
        ],
      ),
    ],
  );

  Widget _buildPreviewList() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${'preview_results'.tr()} (${_extractedData.length})',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: _extractedData.isEmpty
              ? Center(
                  child: Text(
                    'no_data'.tr(),
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.separated(
                  itemCount: _extractedData.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (c, i) => ListTile(
                    dense: true,
                    title: Text(_extractedData[i]['source'] ?? ''),
                    subtitle: Text(
                      "K: ${_extractedData[i]['key']} | T: ${_extractedData[i]['target']}",
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
        ),
      ),
    ],
  );

  Widget _selBtn(String l, int t) => FilledButton.tonal(
    onPressed: () => _assignSelection(t),
    style: FilledButton.styleFrom(padding: EdgeInsets.zero),
    child: Text(l, style: const TextStyle(fontSize: 11)),
  );

  Widget _buildUploadButton() => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: _isUploading || _extractedData.isEmpty ? null : _handleUpload,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: _isUploading
          ? const CircularProgressIndicator()
          : Text('upload_and_create_project'.tr()),
    ),
  );

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles(withData: true);
    if (r != null) _processFileData(r.files.single.name, r.files.single.bytes!);
  }

  Future<void> _handleUpload() async {
    setState(() => _isUploading = true);
    try {
      final title = _fileName!.split('.').first;
      final sid = await widget.service.createSpreadsheet(title);
      if (sid != null) {
        await widget.service.uploadInitialData(
          sid,
          ['Key', 'Source', 'Target'],
          _extractedData
              .map((e) => [e['key']!, e['source']!, e['target']!])
              .toList(),
        );

        // 별도 저장 구조 생성
        final meta = FileStructureMetadata(
          filePrefix: _filePrefix,
          regexPrefix: _regexPrefix,
          sep1: _sep1,
          sep2: _sep2,
          regexSuffix: _regexSuffix,
          fileSuffix: _fileSuffix,
          finalRegex: _finalRegex,
        );

        widget.onAdd(
          FlashcardSet(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title,
            description: "", // 더 이상 사용하지 않음
            sheetId: sid,
            gid: 0,
            keyColIdx: 0,
            frontColIdx: 1,
            backColIdx: 2,
            lastSynced: DateTime.now(),
            lastAccessed: DateTime.now(),
            metadata: Map<String, String>.from(meta.toJson()),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}
