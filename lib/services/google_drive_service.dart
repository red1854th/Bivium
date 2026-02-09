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

  /// 폴더 콘텐츠 탐색 복구
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

  /// 스프레드시트 목록 가져오기 복구
  Future<List<SheetFile>> getSpreadsheets() async {
    final client = await _getAuthenticatedClient();
    if (client == null) return [];
    final driveApi = drive.DriveApi(client);
    try {
      final fileList = await driveApi.files.list(
        q: "mimeType='application/vnd.google-apps.spreadsheet' and trashed=false",
        pageSize: 100,
        $fields: 'files(id, name, modifiedTime)',
        orderBy: 'modifiedTime desc',
      );
      if (fileList.files == null) return [];
      return fileList.files!
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

  /// 시트 데이터 로드 (GID 할당 포함)
  Future<List<Flashcard>> getFlashcards(FlashcardSet set) async {
    final client = await _getAuthenticatedClient();
    if (client == null) return [];
    final sheetsApi = sheets.SheetsApi(client);
    try {
      final spreadsheet = await sheetsApi.spreadsheets.get(
        set.sheetId,
        includeGridData: true,
      );
      final firstSheet = spreadsheet.sheets![0];

      // GID 할당
      set.gid = firstSheet.properties?.sheetId ?? 0;

      final List<Flashcard> cards = [];
      final rowData = firstSheet.data?[0].rowData;
      if (rowData == null) return [];

      for (int i = 1; i < rowData.length; i++) {
        final rowValues = rowData[i].values;
        if (rowValues == null) continue;

        bool flagged = false;
        if (set.frontColIdx < rowValues.length) {
          final rgb = rowValues[set.frontColIdx]
              .effectiveFormat
              ?.backgroundColorStyle
              ?.rgbColor;
          if (rgb != null) {
            flagged =
                (rgb.red ?? 0) > 0.8 &&
                (rgb.green ?? 0) > 0.8 &&
                (rgb.blue ?? 0) < 0.6;
          }
        }
        final rawRow = rowValues
            .map(
              (v) =>
                  v.effectiveValue?.stringValue ??
                  v.effectiveValue?.numberValue?.toString(),
            )
            .toList();
        final card = Flashcard.fromRow(rawRow, set);
        card.isFlagged = flagged;
        cards.add(card);
      }
      return cards;
    } catch (e) {
      debugPrint('데이터 로드 실패: $e');
      return [];
    }
  }

  /// 헤더 가져오기 복구
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

  /// 카드 업데이트
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
