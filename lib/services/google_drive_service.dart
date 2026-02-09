import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;

/// 오류 해결 1: 드라이브 탐색을 위한 데이터 모델 추가
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

/// 오류 해결 2: 프리뷰 데이터를 포함하도록 시트 파일 모델 수정
class SheetFile {
  final String id;
  final String name;
  final DateTime modifiedTime;
  final List<String>? previewData; // Grid View 미리보기용

  SheetFile({
    required this.id,
    required this.name,
    required this.modifiedTime,
    this.previewData,
  });
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

  /// 오류 해결 3: 폴더 콘텐츠를 가져오는 메서드 추가
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

  /// 스프레드시트 목록 가져오기
  Future<List<SheetFile>> getSpreadsheets() async {
    final client = await _getAuthenticatedClient();
    if (client == null) return [];

    final driveApi = drive.DriveApi(client);
    try {
      final fileList = await driveApi.files.list(
        q: "mimeType='application/vnd.google-apps.spreadsheet' and 'me' in owners and trashed=false",
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
              previewData: [], // 초기화
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('목록 가져오기 실패: $e');
      return [];
    }
  }

  Future<List<String>> getSpreadsheetHeaders(String spreadsheetId) async {
    try {
      final client = await _getAuthenticatedClient();
      if (client == null) return [];

      final sheetsApi = sheets.SheetsApi(client);

      // 첫 번째 행(A1부터 Z1까지)의 데이터를 요청합니다.
      // 필요에 따라 범위를 더 넓힐 수 있습니다.
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        'A1:Z1',
      );

      final values = response.values;
      if (values == null || values.isEmpty) return [];

      // 첫 번째 행의 데이터를 문자열 리스트로 변환하여 반환합니다.
      return values[0].map((cell) => cell.toString()).toList();
    } catch (e) {
      debugPrint('헤더 가져오기 실패: $e');
      return [];
    }
  }

  /// 셀 업데이트 로직 (기존 유지)
  Future<void> updateFlashcardField({
    required String spreadsheetId,
    required int cardIndex,
    required int columnIdx,
    required String value,
  }) async {
    if (spreadsheetId.isEmpty) return;
    final int row = cardIndex + 2;
    final String columnLetter = String.fromCharCode(65 + columnIdx);
    final String range = '$columnLetter$row';
    await updateSpreadsheetCell(spreadsheetId, range, value);
  }

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
      rethrow;
    }
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
