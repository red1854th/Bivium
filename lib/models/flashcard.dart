class Flashcard {
  final String key;
  final int groupDepth; // 구글 시트에서 가져온 그룹 깊이 (UI 들여쓰기용)
  bool isCollapsed; // 현재 행의 접힘 상태
  String front;
  String back;
  String remark;
  bool isFlagged;
  List<String> issues;
  final int groupStartIndex; // parent가 컨트롤하는 그룹의 시작 행 인덱스
  final int groupEndIndex; // parent가 컨트롤하는 그룹의 끝 행 인덱스
  final int controlGroupDepth; // parent가 컨트롤하는 그룹의 depth (API 전송용)

  Flashcard({
    this.key = '',
    required this.groupDepth,
    this.isCollapsed = false,
    required this.front,
    required this.back,
    this.remark = '',
    this.isFlagged = false,
    List<String>? issues,
    required this.groupStartIndex,
    required this.groupEndIndex,
    this.controlGroupDepth = 0,
  }) : issues = issues ?? [];

  /// 구글 시트 데이터를 Flashcard 객체로 변환
  factory Flashcard.fromGridData({
    required List<Object?> rowValues,
    required int depth,
    required bool collapsed,
    required FlashcardSet set,
    required int rowIndex,
    required int groupStartIndex,
    required int groupEndIndex,
    required int controlGroupDepth,
    bool isFlaggedFromColor = false, // 배경색 판별 결과 추가
  }) {
    String getVal(int colIdx) {
      if (colIdx >= 0 && colIdx < rowValues.length) {
        return rowValues[colIdx]?.toString() ?? '';
      }
      return '';
    }

    return Flashcard(
      front: getVal(set.frontColIdx),
      back: getVal(set.backColIdx),
      remark: getVal(set.remarkColIdx),
      key: set.keyColIdx != -1 ? getVal(set.keyColIdx) : '',
      isFlagged: isFlaggedFromColor, // 전달받은 플래그 값 할당
      groupDepth: depth,
      isCollapsed: collapsed,
      groupStartIndex: groupStartIndex,
      groupEndIndex: groupEndIndex,
      controlGroupDepth: controlGroupDepth,
    );
  }

  /// 그룹 정보가 없는 일반 행 생성 시 사용
  factory Flashcard.fromRow(List<Object?> row, int index, FlashcardSet set) {
    return Flashcard.fromGridData(
      rowValues: row,
      depth: 0,
      collapsed: false,
      set: set,
      rowIndex: index,
      groupStartIndex: index,
      groupEndIndex: index + 1,
      controlGroupDepth: 0,
    );
  }

  /// 상태 변경을 위한 복사 메서드
  Flashcard copyWith({
    String? front,
    String? back,
    bool? isCollapsed,
    bool? isFlagged,
    int? groupDepth,
    int? groupStartIndex,
    int? groupEndIndex,
    int? controlGroupDepth,
  }) {
    return Flashcard(
      key: key,
      front: front ?? this.front,
      back: back ?? this.back,
      isCollapsed: isCollapsed ?? this.isCollapsed,
      isFlagged: isFlagged ?? this.isFlagged,
      groupDepth: groupDepth ?? this.groupDepth,
      groupStartIndex: groupStartIndex ?? this.groupStartIndex,
      groupEndIndex: groupEndIndex ?? this.groupEndIndex,
      controlGroupDepth: controlGroupDepth ?? this.controlGroupDepth,
      issues: issues,
      remark: remark,
    );
  }
}

class FlashcardSet {
  final String id;
  String title;
  String description;
  String sheetId;
  int gid;
  int frontColIdx;
  int backColIdx;
  int keyColIdx;
  int remarkColIdx;
  DateTime lastSynced;
  DateTime lastAccessed;
  Map<String, dynamic> qcResults;
  String? extractRegex;
  Map<String, String>? metadata;

  FlashcardSet({
    required this.id,
    required this.title,
    this.description = '',
    required this.sheetId,
    this.gid = 0,
    required this.frontColIdx,
    required this.backColIdx,
    this.keyColIdx = -1,
    this.remarkColIdx = -1,
    required this.lastSynced,
    required this.lastAccessed,
    Map<String, dynamic>? qcResults,
    this.extractRegex,
    this.metadata,
  }) : qcResults = qcResults ?? {};

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'sheetId': sheetId,
    'gid': gid,
    'frontColIdx': frontColIdx,
    'backColIdx': backColIdx,
    'keyColIdx': keyColIdx,
    'remarkColIdx': remarkColIdx,
    'lastSynced': lastSynced.toIso8601String(),
    'lastAccessed': lastAccessed.toIso8601String(),
    'qcResults': qcResults,
    'extractRegex': extractRegex,
    'metadata': metadata,
  };

  factory FlashcardSet.fromJson(Map<String, dynamic> json) => FlashcardSet(
    id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
    title: json['title'],
    description: json['description'] ?? '',
    sheetId: json['sheetId'],
    gid: json['gid'] ?? 0,
    frontColIdx: json['frontColIdx'],
    backColIdx: json['backColIdx'],
    keyColIdx: json['keyColIdx'] ?? -1,
    remarkColIdx: json['remarkColIdx'] ?? -1,
    lastSynced: DateTime.parse(json['lastSynced']),
    lastAccessed: DateTime.parse(json['lastAccessed'] ?? json['lastSynced']),
    qcResults: json['qcResults'] != null
        ? Map<String, dynamic>.from(json['qcResults'])
        : {},
    extractRegex: json['extractRegex'],
    metadata: json['metadata'] != null
        ? Map<String, String>.from(json['metadata'])
        : null,
  );

  FlashcardSet copyWith({
    String? id,
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
    String? extractRegex,
    Map<String, String>? metadata,
  }) {
    return FlashcardSet(
      id: id ?? this.id,
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
      extractRegex: extractRegex ?? this.extractRegex,
      metadata: metadata ?? this.metadata,
    );
  }
}
