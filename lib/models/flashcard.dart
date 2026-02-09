class Flashcard {
  final String key;
  String front;
  String back;
  String remark; // 비고 데이터가 저장되는 필드
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

  /// 구글 시트의 한 줄(Row)을 Flashcard 객체로 변환하는 메서드
  factory Flashcard.fromRow(List<Object?> row, FlashcardSet set) {
    String getVal(int colIdx) {
      if (colIdx >= 0 && colIdx < row.length) {
        return row[colIdx]?.toString() ?? '';
      }
      return '';
    }

    return Flashcard(
      front: getVal(set.frontColIdx),
      back: getVal(set.backColIdx),
      remark: getVal(set.remarkColIdx),
      key: set.keyColIdx != -1 ? getVal(set.keyColIdx) : '',
    );
  }
}

class FlashcardSet {
  String title;
  String description;
  String sheetId; // 스프레드시트 파일 ID
  int gid; // [수정] 특정 탭(시트)의 고유 ID (400 에러 방지용)
  int frontColIdx;
  int backColIdx;
  int keyColIdx;
  int remarkColIdx;
  DateTime lastSynced;
  DateTime lastAccessed;
  Map<String, dynamic> qcResults;

  FlashcardSet({
    required this.title,
    this.description = '',
    required this.sheetId,
    this.gid = 0, // [추가] 기본값 0
    required this.frontColIdx,
    required this.backColIdx,
    this.keyColIdx = -1,
    this.remarkColIdx = -1,
    required this.lastSynced,
    required this.lastAccessed,
    Map<String, dynamic>? qcResults,
  }) : qcResults = qcResults ?? {};

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'sheetId': sheetId,
    'gid': gid, // [추가] JSON 저장
    'frontColIdx': frontColIdx,
    'backColIdx': backColIdx,
    'keyColIdx': keyColIdx,
    'remarkColIdx': remarkColIdx,
    'lastSynced': lastSynced.toIso8601String(),
    'lastAccessed': lastAccessed.toIso8601String(),
    'qcResults': qcResults,
  };

  factory FlashcardSet.fromJson(Map<String, dynamic> json) => FlashcardSet(
    title: json['title'],
    description: json['description'] ?? '',
    sheetId: json['sheetId'],
    gid: json['gid'] ?? 0, // [추가] JSON 파싱
    frontColIdx: json['frontColIdx'],
    backColIdx: json['backColIdx'],
    keyColIdx: json['keyColIdx'] ?? -1,
    remarkColIdx: json['remarkColIdx'] ?? -1,
    lastSynced: DateTime.parse(json['lastSynced']),
    lastAccessed: DateTime.parse(json['lastAccessed'] ?? json['lastSynced']),
    qcResults: json['qcResults'] != null
        ? Map<String, dynamic>.from(json['qcResults'])
        : {},
  );

  /// 특정 필드만 변경하여 새로운 객체를 생성하는 메서드
  FlashcardSet copyWith({
    String? title,
    String? description,
    String? sheetId,
    int? gid,
    int? frontColIdx,
    int? backColIdx,
    int? keyColIdx,
    int? remarkColIdx,
    DateTime? lastSynced,
    DateTime? lastAccessed,
    Map<String, dynamic>? qcResults,
  }) {
    return FlashcardSet(
      title: title ?? this.title,
      description: description ?? this.description,
      sheetId: sheetId ?? this.sheetId,
      gid: gid ?? this.gid,
      frontColIdx: frontColIdx ?? this.frontColIdx,
      backColIdx: backColIdx ?? this.backColIdx,
      keyColIdx: keyColIdx ?? this.keyColIdx,
      remarkColIdx: remarkColIdx ?? this.remarkColIdx,
      lastSynced: lastSynced ?? this.lastSynced,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      qcResults: qcResults ?? this.qcResults,
    );
  }
}
