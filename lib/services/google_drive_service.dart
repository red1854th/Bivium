import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import '../models/flashcard.dart';

class DriveItem {
  final String id;
  final String name;
  final bool isFolder;
  final bool isSpreadsheet;
  final DateTime modifiedTime;

  DriveItem({
    required this.id,
    required this.name,
    required this.isFolder,
    required this.isSpreadsheet,
    required this.modifiedTime,
  });
}

class SheetFile {
  final String id;
  final String name;
  final DateTime modifiedTime;

  SheetFile({required this.id, required this.name, required this.modifiedTime});
}

class GoogleDriveService {
  static const _scopes = [
    drive.DriveApi.driveScope,
    sheets.SheetsApi.spreadsheetsScope,
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<GoogleSignInAccount?> signInSilently() =>
      _googleSignIn.signInSilently();
  Future<GoogleSignInAccount?> signIn() => _googleSignIn.signIn();
  Future<void> signOut() => _googleSignIn.signOut();

  Future<http.Client?> _getAuthenticatedClient() async {
    GoogleSignInAccount? googleUser =
        await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final headers = await googleUser.authHeaders;
    return GoogleAuthClient(headers);
  }

  /// 폴더 콘텐츠 탐색
  Future<List<DriveItem>> getFolderContents(String? folderId) async {
    final client = await _getAuthenticatedClient();
    if (client == null) return [];
    final driveApi = drive.DriveApi(client);
    try {
      final parentId = folderId ?? 'root';
      final query = "'$parentId' in parents and trashed=false";
      final fileList = await driveApi.files.list(
        q: query,
        pageSize: 100,
        $fields: 'files(id, name, mimeType, modifiedTime)',
        orderBy: 'folder,name',
      );
      if (fileList.files == null) return [];
      return fileList.files!
          .map(
            (file) => DriveItem(
              id: file.id ?? '',
              name: file.name ?? 'Untitled',
              isFolder: file.mimeType == 'application/vnd.google-apps.folder',
              isSpreadsheet:
                  file.mimeType == 'application/vnd.google-apps.spreadsheet',
              modifiedTime: file.modifiedTime ?? DateTime.now(),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('폴더 탐색 실패: $e');
      return [];
    }
  }

  /// 스프레드시트 목록 가져오기
  Future<List<SheetFile>> getSpreadsheets() async {
    final client = await _getAuthenticatedClient();
    if (client == null) return [];
    final driveApi = drive.DriveApi(client);
    try {
      final fileList = await driveApi.files.list(
        q: "mimeType='application/vnd.google-apps.spreadsheet' and trashed=false",
        pageSize: 100,
        $fields: 'files(id, name, modifiedTime, capabilities(canEdit))',
        orderBy: 'modifiedTime desc',
      );

      if (fileList.files == null) return [];

      return fileList.files!
          .where((file) => file.capabilities?.canEdit ?? false)
          .map(
            (file) => SheetFile(
              id: file.id ?? '',
              name: file.name ?? 'Untitled',
              modifiedTime: file.modifiedTime ?? DateTime.now(),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('목록 가져오기 실패: $e');
      return [];
    }
  }

  /// 카드 데이터 로드 (접힘 상태 포함)
  Future<List<Flashcard>> getFlashcards(FlashcardSet set) async {
    final client = await _getAuthenticatedClient();
    if (client == null) return [];
    final sheetsApi = sheets.SheetsApi(client);

    try {
      final basicSpreadsheet = await sheetsApi.spreadsheets.get(
        set.sheetId,
        includeGridData: false,
      );
      final targetSheet = basicSpreadsheet.sheets!.firstWhere(
        (s) => s.properties?.sheetId == set.gid,
        orElse: () => basicSpreadsheet.sheets![0],
      );

      final String realTitle = targetSheet.properties?.title ?? "";
      final String escapedTitle = "'${realTitle.replaceAll("'", "''")}'";

      final spreadsheet = await sheetsApi.spreadsheets.get(
        set.sheetId,
        ranges: ["$escapedTitle!A:A"],
        includeGridData: true,
      );

      final sheet = spreadsheet.sheets!.firstWhere(
        (s) => s.properties?.sheetId == set.gid,
        orElse: () => spreadsheet.sheets![0],
      );

      final rowGroups = sheet.rowGroups ?? [];
      final rowMetadata = sheet.data?.first.rowMetadata ?? [];

      final response = await sheetsApi.spreadsheets.values.get(
        set.sheetId,
        "$escapedTitle!A:Z",
      );

      final List<List<Object?>> values = response.values ?? [];
      if (values.isEmpty) return [];

      final List<Flashcard> cards = [];

      for (int i = 1; i < values.length; i++) {
        final List<Object?> rowValues = values[i];

        // 1. 이 행이 "속한" 가장 깊은 그룹의 depth (UI 들여쓰기용)
        int memberDepth = 0;
        for (var group in rowGroups) {
          final start = group.range?.startIndex ?? 0;
          final end = group.range?.endIndex ?? 0;
          final d = group.depth ?? 0;
          if (i >= start && i < end && d > memberDepth) {
            memberDepth = d;
          }
        }

        // 2. 이 행이 parent로서 "컨트롤하는" 그룹 찾기
        //    Google Sheets에서 parent 행은 그룹 range 바로 앞에 위치 (startIndex - 1)
        //    따라서 startIndex == i + 1인 그룹을 찾으면 됨
        int controlStart = i;
        int controlEnd = i + 1;
        int controlDepth = 0;
        bool foundControl = false;
        for (var group in rowGroups) {
          final start = group.range?.startIndex ?? 0;
          final end = group.range?.endIndex ?? 0;
          final d = group.depth ?? 0;
          if (start == i + 1) {
            // 여러 그룹이 같은 startIndex를 가질 수 있으므로 가장 얕은 depth 선택
            if (!foundControl || d < controlDepth) {
              controlStart = start;
              controlEnd = end;
              controlDepth = d;
              foundControl = true;
            }
          }
        }

        // isCollapsedBySheet 판별 로직 (동일)
        bool isCollapsedBySheet = false;
        if (i + 1 < rowMetadata.length) {
          if (rowMetadata[i + 1].hiddenByUser == true) {
            isCollapsedBySheet = true;
          }
        }

        cards.add(
          Flashcard.fromGridData(
            rowValues: rowValues,
            depth: memberDepth, // UI 들여쓰기용 (이 행이 속한 그룹의 depth)
            collapsed: isCollapsedBySheet,
            set: set,
            rowIndex: i,
            groupStartIndex: controlStart, // parent가 컨트롤하는 그룹의 range
            groupEndIndex: controlEnd,
            controlGroupDepth: controlDepth, // parent가 컨트롤하는 그룹의 depth (API용)
          ),
        );
      }
      return cards;
    } catch (e) {
      debugPrint('데이터 로드 실패: $e');
      return [];
    }
  }

  Future<void> updateRowGroupExpansion({
    required String spreadsheetId,
    required int sheetId,
    required int startIndex,
    required int endIndex,
    required bool collapse,
    required int depth, // 이 값이 실제 해당 하위 그룹의 depth와 일치해야 합니다.
  }) async {
    final client = await _getAuthenticatedClient();
    if (client == null) return;
    final sheetsApi = sheets.SheetsApi(client);

    final request = sheets.BatchUpdateSpreadsheetRequest(
      requests: [
        sheets.Request(
          updateDimensionGroup: sheets.UpdateDimensionGroupRequest(
            dimensionGroup: sheets.DimensionGroup(
              range: sheets.DimensionRange(
                sheetId: sheetId,
                dimension: "ROWS",
                startIndex: startIndex,
                endIndex: endIndex,
              ),
              collapsed: collapse,
              depth: depth, // 정확한 depth 지정이 핵심입니다.
            ),
            // 명시적으로 collapsed 필드만 업데이트하도록 설정
            fields: "collapsed",
          ),
        ),
      ],
    );

    try {
      await sheetsApi.spreadsheets.batchUpdate(request, spreadsheetId);
    } catch (e) {
      debugPrint('그룹 접기 동기화 실패: $e');
    }
  }

  /// 헤더 가져오기
  Future<List<String>> getSpreadsheetHeaders(String spreadsheetId) async {
    final client = await _getAuthenticatedClient();
    if (client == null) return [];
    final sheetsApi = sheets.SheetsApi(client);
    try {
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        'A1:ZZ1',
      );
      if (response.values == null || response.values!.isEmpty) return [];
      return response.values![0].map((cell) => cell.toString()).toList();
    } catch (e) {
      debugPrint('헤더 로드 실패: $e');
      return [];
    }
  }

  /// 특정 셀 업데이트
  Future<void> updateSpreadsheetCell(
    String spreadsheetId,
    String range,
    String value,
  ) async {
    final client = await _getAuthenticatedClient();
    if (client == null) return;
    final sheetsApi = sheets.SheetsApi(client);
    final valueRange = sheets.ValueRange.fromJson({
      'values': [
        [value],
      ],
    });
    await sheetsApi.spreadsheets.values.update(
      valueRange,
      spreadsheetId,
      range,
      valueInputOption: 'USER_ENTERED',
    );
  }

  /// 카드 데이터 업데이트 (플래그 포함)
  Future<void> updateFlashcard({
    required String spreadsheetId,
    required int cardIndex,
    required FlashcardSet setInfo,
    required Flashcard card,
  }) async {
    final client = await _getAuthenticatedClient();
    if (client == null) return;
    final sheetsApi = sheets.SheetsApi(client);

    final color = card.isFlagged
        ? sheets.Color(red: 1.0, green: 0.98, blue: 0.77)
        : sheets.Color(red: 1.0, green: 1.0, blue: 1.0);

    final batchRequest = sheets.BatchUpdateSpreadsheetRequest(
      requests: [
        _buildCellReq(
          setInfo.gid,
          cardIndex,
          setInfo.frontColIdx,
          card.front,
          color,
        ),
        _buildCellReq(
          setInfo.gid,
          cardIndex,
          setInfo.backColIdx,
          card.back,
          color,
        ),
      ],
    );
    await sheetsApi.spreadsheets.batchUpdate(batchRequest, spreadsheetId);
  }

  sheets.Request _buildCellReq(
    int gid,
    int row,
    int col,
    String val,
    sheets.Color? color,
  ) {
    return sheets.Request(
      updateCells: sheets.UpdateCellsRequest(
        range: sheets.GridRange(
          sheetId: gid,
          startRowIndex: row + 1,
          endRowIndex: row + 2,
          startColumnIndex: col,
          endColumnIndex: col + 1,
        ),
        rows: [
          sheets.RowData(
            values: [
              sheets.CellData(
                userEnteredValue: sheets.ExtendedValue(stringValue: val),
                userEnteredFormat: color != null
                    ? sheets.CellFormat(
                        backgroundColorStyle: sheets.ColorStyle(
                          rgbColor: color,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ],
        fields: color != null
            ? 'userEnteredValue,userEnteredFormat.backgroundColorStyle'
            : 'userEnteredValue',
      ),
    );
  }
} // GoogleDriveService 클래스 끝

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  GoogleAuthClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
