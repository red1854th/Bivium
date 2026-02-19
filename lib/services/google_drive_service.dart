import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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

  static const _isLoggedInKey = 'is_logged_in';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '1068673942991-r0ee89o9vgeddlpleqq73hp3l9o4e0bg.apps.googleusercontent.com'
        : null,
    scopes: _scopes,
  );

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;
  Future<GoogleSignInAccount?>? _ongoingSignIn;

  Future<GoogleSignInAccount?> signInSilentlyCheck() async {
    if (_googleSignIn.currentUser != null) return _googleSignIn.currentUser;
    if (_ongoingSignIn != null) return _ongoingSignIn;
    _ongoingSignIn = _performSignInSilently();
    try {
      return await _ongoingSignIn;
    } finally {
      _ongoingSignIn = null;
    }
  }

  Future<GoogleSignInAccount?> _performSignInSilently() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_isLoggedInKey) ?? false)) return null;
      final account = await _googleSignIn.signInSilently();
      if (account != null) await prefs.setBool(_isLoggedInKey, true);
      return account;
    } catch (e) {
      debugPrint("조용히 로그인 체크 에러: $e");
      return null;
    }
  }

  Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_isLoggedInKey, true);
      }
      return account;
    } catch (e) {
      debugPrint("로그인 실패: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isLoggedInKey);
    try {
      if (kIsWeb) await _googleSignIn.disconnect();
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint("로그아웃 에러: $e");
    }
  }

  Future<http.Client?> _getAuthenticatedClient() async {
    GoogleSignInAccount? account = _googleSignIn.currentUser;
    if (account == null) {
      account = await signInSilentlyCheck();
      if (account == null) return null;
    }
    final authHeaders = await account.authHeaders;
    return GoogleAuthClient(authHeaders, _clientRecall);
  }

  Future<Map<String, String>?> _clientRecall() async {
    try {
      final account = await _googleSignIn.signInSilently();
      return await account?.authHeaders;
    } catch (e) {
      debugPrint("토큰 갱신 실패: $e");
      return null;
    }
  }

  // --- 비즈니스 로직 ---

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
      return fileList.files?.map((file) => _mapToDriveItem(file)).toList() ??
          [];
    } catch (e) {
      debugPrint('폴더 탐색 실패: $e');
      return [];
    }
  }

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
      return fileList.files!
          .where((file) => file.capabilities?.canEdit ?? false)
          .map((file) => _mapToSheetFile(file))
          .toList();
    } catch (e) {
      debugPrint('목록 가져오기 실패: $e');
      return [];
    }
  }

  // --- 검색 로직 추가 ---

  Future<List<DriveItem>> searchAllContents(String searchQuery) async {
    final client = await _getAuthenticatedClient();
    if (client == null) return [];
    final driveApi = drive.DriveApi(client);
    try {
      final query = "name contains '$searchQuery' and trashed = false";
      final fileList = await driveApi.files.list(
        q: query,
        pageSize: 50,
        $fields: 'files(id, name, mimeType, modifiedTime)',
        orderBy: 'folder,name',
      );
      return fileList.files?.map((file) => _mapToDriveItem(file)).toList() ??
          [];
    } catch (e) {
      debugPrint('전체 검색 실패: $e');
      return [];
    }
  }

  Future<List<SheetFile>> searchSpreadsheets(String searchQuery) async {
    final client = await _getAuthenticatedClient();
    if (client == null) return [];
    final driveApi = drive.DriveApi(client);
    try {
      final query =
          "mimeType='application/vnd.google-apps.spreadsheet' and name contains '$searchQuery' and trashed=false";
      final fileList = await driveApi.files.list(
        q: query,
        pageSize: 50,
        $fields: 'files(id, name, modifiedTime)',
        orderBy: 'modifiedTime desc',
      );
      return fileList.files?.map((file) => _mapToSheetFile(file)).toList() ??
          [];
    } catch (e) {
      debugPrint('시트 검색 실패: $e');
      return [];
    }
  }

  // 매핑 헬퍼
  DriveItem _mapToDriveItem(drive.File file) {
    return DriveItem(
      id: file.id ?? '',
      name: file.name ?? 'Untitled',
      isFolder: file.mimeType == 'application/vnd.google-apps.folder',
      isSpreadsheet: file.mimeType == 'application/vnd.google-apps.spreadsheet',
      modifiedTime: file.modifiedTime ?? DateTime.now(),
    );
  }

  SheetFile _mapToSheetFile(drive.File file) {
    return SheetFile(
      id: file.id ?? '',
      name: file.name ?? 'Untitled',
      modifiedTime: file.modifiedTime ?? DateTime.now(),
    );
  }

  Future<List<Flashcard>> getFlashcards(FlashcardSet set) async {
    final client = await _getAuthenticatedClient();
    if (client == null) return [];

    final sheetsApi = sheets.SheetsApi(client);
    try {
      final metadata = await sheetsApi.spreadsheets.get(
        set.sheetId,
        $fields: 'sheets.properties',
      );
      final targetSheet = metadata.sheets?.firstWhere(
        (s) => s.properties?.sheetId == set.gid,
        orElse: () => metadata.sheets![0],
      );
      if (targetSheet?.properties?.sheetId != null &&
          set.gid != targetSheet!.properties!.sheetId) {
        set.gid = targetSheet.properties!.sheetId!;
      }

      final String realTitle = targetSheet?.properties?.title ?? "";
      final String escapedTitle = "'${realTitle.replaceAll("'", "''")}'";

      final spreadsheet = await sheetsApi.spreadsheets.get(
        set.sheetId,
        includeGridData: true,
        ranges: [escapedTitle],
        $fields:
            'sheets(rowGroups,data(rowData(values(effectiveFormat(backgroundColor,backgroundColorStyle))),rowMetadata(hiddenByUser)))',
      );

      final sheet = spreadsheet.sheets![0];
      final rowGroups = sheet.rowGroups ?? [];
      final rowMetadata = sheet.data?.first.rowMetadata ?? [];
      final rowData = sheet.data?.first.rowData ?? [];

      final response = await sheetsApi.spreadsheets.values.get(
        set.sheetId,
        escapedTitle,
      );

      final List<List<Object?>> values = response.values ?? [];
      if (values.isEmpty) return [];

      final List<Flashcard> cards = [];
      for (int i = 1; i < values.length; i++) {
        final List<Object?> rowValues = values[i];
        bool isFlaggedByColor = false;

        if (i < rowData.length) {
          final cells = rowData[i].values;
          if (cells != null && cells.length > set.frontColIdx) {
            final bgColor = cells[set.frontColIdx]
                .effectiveFormat
                ?.backgroundColorStyle
                ?.rgbColor;
            if (bgColor != null) {
              if ((bgColor.red ?? 0) > 0.9 && (bgColor.blue ?? 1.0) < 0.85) {
                isFlaggedByColor = true;
              }
            }
          }
        }

        int memberDepth = 0;
        for (var group in rowGroups) {
          final start = group.range?.startIndex ?? 0;
          final end = group.range?.endIndex ?? 0;
          if (i >= start && i < end && (group.depth ?? 0) > memberDepth) {
            memberDepth = group.depth!;
          }
        }

        int controlStart = i, controlEnd = i + 1, controlDepth = 0;
        bool foundControl = false;
        for (var group in rowGroups) {
          if ((group.range?.startIndex ?? 0) == i + 1) {
            if (!foundControl || (group.depth ?? 0) < controlDepth) {
              controlStart = group.range!.startIndex!;
              controlEnd = group.range!.endIndex!;
              controlDepth = group.depth!;
              foundControl = true;
            }
          }
        }

        bool isCollapsedBySheet = false;
        if (i + 1 < rowMetadata.length &&
            rowMetadata[i + 1].hiddenByUser == true) {
          isCollapsedBySheet = true;
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
            isFlaggedFromColor: isFlaggedByColor,
          ),
        );
      }
      return cards;
    } catch (e) {
      debugPrint('데이터 로드 실패: $e');
      return [];
    }
  }

  Future<String> getSpreadsheetCell(String spreadsheetId, String range) async {
    final client = await _getAuthenticatedClient();
    if (client == null) return "";

    final sheetsApi = sheets.SheetsApi(client);
    try {
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        range,
      );
      if (response.values == null || response.values!.isEmpty) return "";
      return response.values![0][0]?.toString() ?? "";
    } catch (e) {
      debugPrint('셀 데이터 로드 실패: $e');
      return "";
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

  Future<({List<String> headers, int gid, String title})?> getSpreadsheetInfo(
    String spreadsheetId,
  ) async {
    final client = await _getAuthenticatedClient();
    if (client == null) return null;

    final sheetsApi = sheets.SheetsApi(client);
    try {
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
          null,
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

  Future<String?> createSpreadsheet(String title) async {
    final client = await _getAuthenticatedClient();
    if (client == null) return null;

    final sheetsApi = sheets.SheetsApi(client);
    try {
      final spreadsheet = sheets.Spreadsheet(
        properties: sheets.SpreadsheetProperties(title: title),
      );
      final result = await sheetsApi.spreadsheets.create(spreadsheet);
      return result.spreadsheetId;
    } catch (e) {
      debugPrint('시트 생성 실패: $e');
      return null;
    }
  }

  Future<void> uploadInitialData(
    String spreadsheetId,
    List<String> headers,
    List<List<String>> data,
  ) async {
    final client = await _getAuthenticatedClient();
    if (client == null) return;

    final sheetsApi = sheets.SheetsApi(client);
    try {
      final List<List<Object?>> values = [headers, ...data];
      final valueRange = sheets.ValueRange.fromJson({'values': values});
      await sheetsApi.spreadsheets.values.update(
        valueRange,
        spreadsheetId,
        'A1',
        valueInputOption: 'USER_ENTERED',
      );
    } catch (e) {
      debugPrint('데이터 업로드 실패: $e');
    }
  }
}

/// 401 에러 발생 시 토큰 갱신을 시도하는 클라이언트
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final Future<Map<String, String>?> Function() _refreshCallback;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers, this._refreshCallback);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers.addAll(_headers);

    try {
      final response = await _client.send(request);
      if (response.statusCode == 401) {
        debugPrint("401 발생: 토큰 갱신 시도...");
        final newHeaders = await _refreshCallback();
        if (newHeaders != null) {
          final newRequest = _copyRequest(request);
          if (newRequest != null) {
            newRequest.headers.addAll(newHeaders);
            return await _client.send(newRequest);
          }
        }
      }
      return response;
    } catch (e) {
      rethrow;
    }
  }

  http.BaseRequest? _copyRequest(http.BaseRequest request) {
    if (request is http.Request) {
      final newReq = http.Request(request.method, request.url)
        ..bodyBytes = request.bodyBytes
        ..encoding = request.encoding;
      return newReq;
    }
    return null;
  }
}
