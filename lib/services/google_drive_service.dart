import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;
import '../models/flashcard.dart';

/// 드라이브 탐색을 위한 데이터 모델
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

/// 시트 파일 모델 (previewData 제거)
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
      return fileList.files!.map((file) {
        return DriveItem(
          id: file.id ?? '',
          name: file.name ?? 'Untitled',
          isFolder: file.mimeType == 'application/vnd.google-apps.folder',
          isSpreadsheet:
              file.mimeType == 'application/vnd.google-apps.spreadsheet',
          modifiedTime: file.modifiedTime ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('폴더 탐색 실패: $e');
      return [];
    }
  }

  /// 스프레드시트 목록 가져오기 (previewData 관련 로직 삭제)
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

  /// 시트 데이터 로드 (비고 매핑 로직 유지 및 강화)
  Future<List<Flashcard>> getFlashcards(FlashcardSet set) async {
    try {
      final client = await _getAuthenticatedClient();
      if (client == null) return [];

      final sheetsApi = sheets.SheetsApi(client);
      // 데이터 범위 A부터 ZZ까지 넉넉하게 요청
      final response = await sheetsApi.spreadsheets.values.get(
        set.sheetId,
        'A:ZZ',
      );
      final values = response.values;

      if (values == null || values.isEmpty) return [];

      return values.skip(1).map((row) {
        // 특정 열 인덱스의 값을 안전하게 추출
        String getVal(int colIdx) {
          if (colIdx >= 0 && colIdx < row.length) {
            return row[colIdx]?.toString() ?? '';
          }
          return '';
        }

        return Flashcard(
          front: getVal(set.frontColIdx),
          back: getVal(set.backColIdx),
          remark: getVal(set.remarkColIdx), // 불러오기 핵심 지점
          key: set.keyColIdx != -1 ? getVal(set.keyColIdx) : '',
        );
      }).toList();
    } catch (e) {
      debugPrint('카드 데이터 로드 실패: $e');
      return [];
    }
  }

  /// 시트 헤더 가져오기
  Future<List<String>> getSpreadsheetHeaders(String spreadsheetId) async {
    try {
      final client = await _getAuthenticatedClient();
      if (client == null) return [];
      final sheetsApi = sheets.SheetsApi(client);
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

  /// 시트 필드 업데이트
  Future<void> updateFlashcardField({
    required String spreadsheetId,
    required int cardIndex,
    required int columnIdx,
    required String value,
  }) async {
    if (spreadsheetId.isEmpty || columnIdx < 0) return;

    final String columnLetter = _getColName(columnIdx);
    final String range = '$columnLetter${cardIndex + 2}';

    await updateSpreadsheetCell(spreadsheetId, range, value);
  }

  /// 셀 데이터 업데이트 실행
  Future<void> updateSpreadsheetCell(
    String spreadsheetId,
    String range,
    String value,
  ) async {
    try {
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
    } catch (e) {
      debugPrint('셀 업데이트 에러: $e');
      rethrow;
    }
  }

  Future<String?> getSpreadsheetCell(String spreadsheetId, String range) async {
    try {
      // 클래스 내부에 정의된 _getAuthenticatedClient를 호출합니다.
      final client = await _getAuthenticatedClient();
      if (client == null) return null;

      final sheetsApi = sheets.SheetsApi(client);
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        range,
      );

      if (response.values != null &&
          response.values!.isNotEmpty &&
          response.values![0].isNotEmpty) {
        return response.values![0][0].toString();
      }
      return "";
    } catch (e) {
      debugPrint('셀 데이터 로드 실패: $e');
      return null;
    }
  }

  /// 인덱스를 시트 문자(A, B... AA...)로 변환
  String _getColName(int index) {
    String name = "";
    while (index >= 0) {
      name = String.fromCharCode((index % 26) + 65) + name;
      index = (index ~/ 26) - 1;
    }
    return name;
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
