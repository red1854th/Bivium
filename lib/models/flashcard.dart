class Flashcard {
  final String key;
  String front;
  String back;
  String remark;
  bool isFlagged;
  List<String> issues;
  Flashcard({
    this.key = '',
    required this.front,
    required this.back,
    this.remark = '',
    this.isFlagged = false,
    List<String>? issues,
  }) : issues = issues ?? [];
}

class FlashcardSet {
  String title;
  String description; // Added field
  String sheetId;
  int frontColIdx;
  int backColIdx;
  int keyColIdx;
  int remarkColIdx;
  DateTime lastSynced;
  DateTime lastAccessed; // Added field
  Map<String, dynamic> qcResults;

  FlashcardSet({
    required this.title,
    this.description = '', // Added to constructor with default
    required this.sheetId,
    required this.frontColIdx,
    required this.backColIdx,
    this.keyColIdx = -1,
    this.remarkColIdx = -1,
    required this.lastSynced,
    required this.lastAccessed, // Added to constructor
    Map<String, dynamic>? qcResults,
  }) : qcResults = qcResults ?? {};

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description, // Added to toJson
    'sheetId': sheetId,
    'frontColIdx': frontColIdx,
    'backColIdx': backColIdx,
    'keyColIdx': keyColIdx,
    'remarkColIdx': remarkColIdx,
    'lastSynced': lastSynced.toIso8601String(),
    'lastAccessed': lastAccessed.toIso8601String(), // Added to toJson
    'qcResults': qcResults,
  };

  factory FlashcardSet.fromJson(Map<String, dynamic> json) => FlashcardSet(
    title: json['title'],
    description: json['description'] ?? '', // Added to fromJson with fallback
    sheetId: json['sheetId'],
    frontColIdx: json['frontColIdx'],
    backColIdx: json['backColIdx'],
    keyColIdx: json['keyColIdx'] ?? -1,
    remarkColIdx: json['remarkColIdx'] ?? -1,
    lastSynced: DateTime.parse(json['lastSynced']),
    lastAccessed: DateTime.parse(
      json['lastAccessed'] ?? json['lastSynced'],
    ), // Added to fromJson with fallback
    qcResults: json['qcResults'] != null
        ? Map<String, dynamic>.from(json['qcResults'])
        : {},
  );
}
