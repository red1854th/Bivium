import 'package:bivium/models/flashcard.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class GlossaryEntry {
  String source;
  String target;

  GlossaryEntry({required this.source, required this.target});
}

class GlossaryTab extends StatefulWidget {
  final List<Flashcard> cards;

  const GlossaryTab({super.key, required this.cards});

  @override
  // ignore: library_private_types_in_public_api
  _GlossaryTabState createState() => _GlossaryTabState();
}

class _GlossaryTabState extends State<GlossaryTab> {
  final List<GlossaryEntry> _glossary = [];

  void _addGlossaryEntry() {
    final sourceController = TextEditingController();
    final targetController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('add_glossary_entry'.tr()),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: sourceController,
                decoration: InputDecoration(labelText: 'source_label'.tr()),
              ),
              TextField(
                controller: targetController,
                decoration: InputDecoration(labelText: 'target_label'.tr()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('cancel'.tr()),
            ),
            TextButton(
              onPressed: () {
                if (sourceController.text.isNotEmpty &&
                    targetController.text.isNotEmpty) {
                  setState(() {
                    _glossary.add(
                      GlossaryEntry(
                        source: sourceController.text,
                        target: targetController.text,
                      ),
                    );
                  });
                  Navigator.of(context).pop();
                }
              },
              child: Text('add'.tr()),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView.builder(
        itemCount: _glossary.length,
        itemBuilder: (context, index) {
          final entry = _glossary[index];
          return ListTile(
            title: Text(entry.source),
            subtitle: Text(entry.target),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addGlossaryEntry,
        child: const Icon(Icons.add),
      ),
    );
  }
}
