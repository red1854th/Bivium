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

  /// 카드 데이터 로드 (배경색 기반 플래그 판별 포함)
  Future<List<Flashcard>> getFlashcards(FlashcardSet set) async {
    final client = await _getAuthenticatedClient();
    if (client == null) return [];
    final sheetsApi = sheets.SheetsApi(client);

    try {
      // 1. 시트 제목을 먼저 가져옴 (최소한의 메타데이터만 요청)
      final metadata = await sheetsApi.spreadsheets.get(
        set.sheetId,
        $fields: 'sheets.properties',
      );

      final targetSheet = metadata.sheets?.firstWhere(
        (s) => s.properties?.sheetId == set.gid,
        orElse: () => metadata.sheets![0],
      );

      // set.gid가 실제 시트 ID와 다르면 (특히 0으로 잘못 설정되었을 경우) 업데이트
      if (targetSheet?.properties?.sheetId != null &&
          set.gid != targetSheet!.properties!.sheetId) {
        set.gid = targetSheet.properties!.sheetId!;
      }

      final String realTitle = targetSheet?.properties?.title ?? "";
      final String escapedTitle = "'${realTitle.replaceAll("'", "''")}'";

      // 2. 해당 시트의 특정 데이터만 요청 (GridData를 전체가 아닌 해당 시트로 한정)
      // fields를 사용하여 배경색, 그룹 정보, 숨김 상태만 가져옴으로써 페이로드 크기를 획기적으로 줄임
      final spreadsheet = await sheetsApi.spreadsheets.get(
        set.sheetId,
        includeGridData: true,
        ranges: [escapedTitle],
        $fields:
            'sheets(rowGroups,data(rowData(values(effectiveFormat/backgroundColor)),rowMetadata(hiddenByUser)))',
      );

      final sheet = spreadsheet.sheets![0];
      final rowGroups = sheet.rowGroups ?? [];
      final rowMetadata = sheet.data?.first.rowMetadata ?? [];
      final rowData = sheet.data?.first.rowData ?? []; // 메타데이터 (배경색 등)

      // 3. 텍스트 값 가져오기
      final response = await sheetsApi.spreadsheets.values.get(
        set.sheetId,
        escapedTitle,
      );

      final List<List<Object?>> values = response.values ?? [];
      if (values.isEmpty) return [];

      final List<Flashcard> cards = [];

      for (int i = 1; i < values.length; i++) {
        final List<Object?> rowValues = values[i];

        // --- 플래그(배경색) 판별 로직 시작 ---
        bool isFlaggedByColor = false;
        if (i < rowData.length) {
          final cells = rowData[i].values;
          if (cells != null && cells.length > set.frontColIdx) {
            // Front 열의 배경색 확인
            final bgColor = cells[set.frontColIdx]
                .effectiveFormat
                ?.backgroundColorStyle
                ?.rgbColor;
            if (bgColor != null) {
              // 노란색 계열(R:1.0, G:0.98, B:0.77)인지 판별
              // 오차를 감안하여 Red가 높고 Blue가 낮은지 확인
              if ((bgColor.red ?? 0) > 0.9 && (bgColor.blue ?? 1.0) < 0.85) {
                isFlaggedByColor = true;
              }
            }
          }
        }
        // --- 플래그 판별 로직 끝 ---

        // 1. 이 행이 "속한" 가장 깊은 그룹의 depth
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
        int controlStart = i;
        int controlEnd = i + 1;
        int controlDepth = 0;
        bool foundControl = false;
        for (var group in rowGroups) {
          final start = group.range?.startIndex ?? 0;
          final end = group.range?.endIndex ?? 0;
          final d = group.depth ?? 0;
          if (start == i + 1) {
            if (!foundControl || d < controlDepth) {
              controlStart = start;
              controlEnd = end;
              controlDepth = d;
              foundControl = true;
            }
          }
        }

        bool isCollapsedBySheet = false;
        if (i + 1 < rowMetadata.length) {
          if (rowMetadata[i + 1].hiddenByUser == true) {
            isCollapsedBySheet = true;
          }
        }

        cards.add(
          Flashcard.fromGridData(
            rowValues: rowValues,
            depth: memberDepth,
            collapsed: isCollapsedBySheet,
            set: set,
            rowIndex: i,
            groupStartIndex: controlStart,
            groupEndIndex: controlEnd,
            controlGroupDepth: controlDepth,
            isFlaggedFromColor: isFlaggedByColor, // 수정한 Flashcard 모델에 전달
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
    required int depth,
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
              depth: depth,
            ),
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

  /// 시트 정보(헤더, GID, 제목) 가져오기
  Future<({List<String> headers, int gid, String title})?> getSpreadsheetInfo(
    String spreadsheetId,
  ) async {
    final client = await _getAuthenticatedClient();
    if (client == null) return null;
    final sheetsApi = sheets.SheetsApi(client);
    try {
      // 1. 시트 메타데이터 로드 (첫 번째 시트의 GID와 제목 확인)
      final spreadsheet = await sheetsApi.spreadsheets.get(
        spreadsheetId,
        $fields: 'sheets.properties',
      );
      if (spreadsheet.sheets == null || spreadsheet.sheets!.isEmpty) {
        return null;
      }

      final firstSheet = spreadsheet.sheets![0].properties!;
      final int gid = firstSheet.sheetId ?? 0;
      final String title = firstSheet.title ?? "";

      // 2. 해당 시트의 헤더 가져오기
      final String escapedTitle = "'${title.replaceAll("'", "''")}'";
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        '$escapedTitle!1:1',
      );

      final List<String> headers = [];
      if (response.values != null && response.values!.isNotEmpty) {
        headers.addAll(
          response.values![0].map((cell) => cell.toString()).toList(),
        );
      }

      return (headers: headers, gid: gid, title: title);
    } catch (e) {
      debugPrint('시트 정보 로드 실패: $e');
      return null;
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
          null, // 후면(back) 컬럼에는 색상을 적용하지 않음
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
}

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
