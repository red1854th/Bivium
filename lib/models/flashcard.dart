class Flashcard {
  final String key;
  String front;
  String back;
  bool isFlagged;
  List<String> issues;
  Flashcard({
    this.key = '',
    required this.front,
    required this.back,
    this.isFlagged = false,
    List<String>? issues,
  }) : issues = issues ?? [];
}

class FlashcardSet {
  String title;
  String sheetId;
  int frontColIdx;
  int backColIdx;
  int keyColIdx;
  DateTime lastSynced;
  Map<String, dynamic> qcResults;

  FlashcardSet({
    required this.title,
    required this.sheetId,
    required this.frontColIdx,
    required this.backColIdx,
    this.keyColIdx = -1,
    required this.lastSynced,
    Map<String, dynamic>? qcResults,
  }) : qcResults = qcResults ?? {};

  Map<String, dynamic> toJson() => {
    'title': title,
    'sheetId': sheetId,
    'frontColIdx': frontColIdx,
    'backColIdx': backColIdx,
    'keyColIdx': keyColIdx,
    'lastSynced': lastSynced.toIso8601String(),
    'qcResults': qcResults,
  };

  factory FlashcardSet.fromJson(Map<String, dynamic> json) => FlashcardSet(
    title: json['title'],
    sheetId: json['sheetId'],
    frontColIdx: json['frontColIdx'],
    backColIdx: json['backColIdx'],
    keyColIdx: json['keyColIdx'] ?? -1,
    lastSynced: DateTime.parse(json['lastSynced']),
    qcResults: json['qcResults'] != null
        ? Map<String, dynamic>.from(json['qcResults'])
        : {},
  );
}
