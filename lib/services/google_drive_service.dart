import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:http/http.dart' as http;

class GoogleDriveService {
  // 1. Scopes 설정 (콘솔에서 설정한 것과 일치해야 함)
  static const _scopes = [
    drive.DriveApi.driveScope,
    sheets.SheetsApi.spreadsheetsScope,
  ]; // 전체 권한 사용 시

  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: _scopes);

  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  Future<GoogleSignInAccount?> signInSilently() {
    return _googleSignIn.signInSilently();
  }

  Future<GoogleSignInAccount?> signIn() {
    return _googleSignIn.signIn();
  }

  Future<drive.DriveApi?> getDriveApi() async {
    // 2. 구글 로그인 실행
    GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
    // 자동 로그인 실패 시 수동 로그인 시도
    googleUser ??= await _googleSignIn.signIn();
    if (googleUser == null) return null;

    // 3. 인증 정보 가져오기 & 클라이언트 생성
    final headers = await googleUser.authHeaders;
    final client = GoogleAuthClient(headers);

    // 4. Drive API 리턴
    return drive.DriveApi(client);
  }

  Future<void> listDriveFiles() async {
    final driveApi = await getDriveApi();
    if (driveApi == null) {
      debugPrint("로그인에 실패했습니다.");
      return;
    }

    try {
      // 드라이브의 파일 목록 요청
      final fileList = await driveApi.files.list(
        pageSize: 10,
        $fields: 'files(id, name, mimeType)',
      );

      debugPrint('--- 파일 목록 ---');
      if (fileList.files == null || fileList.files!.isEmpty) {
        debugPrint('파일이 없습니다.');
      } else {
        for (var file in fileList.files!) {
          debugPrint('이름: ${file.name}, ID: ${file.id}');
        }
      }
    } catch (e) {
      debugPrint('오류 발생: $e');
    }
  }

  /// 구글 스프레드시트 목록 가져오기
  Future<List<SheetFile>> getSpreadsheets() async {
    final driveApi = await getDriveApi();
    if (driveApi == null) {
      debugPrint("로그인에 실패했습니다.");
      return [];
    }

    try {
      final fileList = await driveApi.files.list(
        q: "mimeType='application/vnd.google-apps.spreadsheet' and 'me' in owners",
        pageSize: 100,
        $fields: 'files(id, name, modifiedTime)',
        orderBy: 'modifiedTime desc',
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        return [];
      }

      return fileList.files!.map((file) {
        return SheetFile(
          id: file.id ?? '',
          name: file.name ?? 'Untitled',
          modifiedTime: file.modifiedTime ?? DateTime.now(),
          previewData: null, // API 호출로 미리보기 데이터 가져오기
        );
      }).toList();
    } catch (e) {
      debugPrint('스프레드시트 목록 가져오기 실패: $e');
      return [];
    }
  }

  /// 특정 폴더의 파일/폴더 목록 가져오기 (폴더 탐색용)
  Future<List<DriveItem>> getFolderContents(String? folderId) async {
    final driveApi = await getDriveApi();
    if (driveApi == null) {
      debugPrint("로그인에 실패했습니다.");
      return [];
    }

    try {
      // folderId가 null이면 루트(My Drive)
      final parentQuery = folderId == null
          ? "'root' in parents"
          : "'$folderId' in parents";

      final query = "$parentQuery and trashed=false and 'me' in owners";

      final fileList = await driveApi.files.list(
        q: query,
        pageSize: 100,
        $fields: 'files(id, name, mimeType, modifiedTime)',
        orderBy: 'folder,name',
      );

      if (fileList.files == null || fileList.files!.isEmpty) {
        return [];
      }

      return fileList.files!.map((file) {
        final isFolder = file.mimeType == 'application/vnd.google-apps.folder';
        final isSpreadsheet =
            file.mimeType == 'application/vnd.google-apps.spreadsheet';

        return DriveItem(
          id: file.id ?? '',
          name: file.name ?? 'Untitled',
          isFolder: isFolder,
          isSpreadsheet: isSpreadsheet,
          modifiedTime: file.modifiedTime ?? DateTime.now(),
          previewData: null, // API 호출로 미리보기 데이터 가져오기
        );
      }).toList();
    } catch (e) {
      debugPrint('폴더 내용 가져오기 실패: $e');
      return [];
    }
  }

  /// Google Sheets URL에서 스프레드시트 ID 추출
  static String extractSheetIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('docs.google.com') &&
          uri.path.contains('/spreadsheets/d/')) {
        final parts = uri.path.split('/');
        for (int i = 0; i < parts.length; i++) {
          if (parts[i] == 'd' && i + 1 < parts.length) {
            return parts[i + 1];
          }
        }
      }
    } catch (e) {
      debugPrint('URL 파싱 실패: $e');
    }
    return '';
  }

  /// 로그아웃
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  /// Google Sheets API로 스프레드시트 미리보기 데이터 가져오기
  Future<List<String>?> getSpreadsheetPreview(String spreadsheetId) async {
    try {
      final driveApi = await getDriveApi();
      if (driveApi == null) return null;

      // Google Sheets API 클라이언트 생성
      GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      googleUser ??= await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final headers = await googleUser.authHeaders;
      final client = GoogleAuthClient(headers);

      final sheetsApi = sheets.SheetsApi(client);

      // 스프레드시트의 첫 번째 시트에서 상위 4행, 3열 데이터 가져오기
      final result = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        'Sheet1!A1:C4',
      );

      if (result.values == null || result.values!.isEmpty) {
        return null;
      }

      return result.values!.map((row) => row.join('\t')).toList();
    } catch (e) {
      debugPrint('스프레드시트 미리보기 가져오기 실패: $e');
      return null;
    }
  }

  /// Preview for card: first sheet, columns A–C, row 1 only.
  Future<List<String>?> getSpreadsheetPreviewCard(String spreadsheetId) async {
    try {
      GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      googleUser ??= await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final headers = await googleUser.authHeaders;
      final client = GoogleAuthClient(headers);
      final sheetsApi = sheets.SheetsApi(client);

      final result = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        'Sheet1!A1:C1',
      );

      if (result.values == null || result.values!.isEmpty) return null;
      final firstRow = result.values!.first;
      return firstRow.map((cell) => cell.toString()).toList();
    } catch (e) {
      debugPrint('스프레드시트 카드 미리보기 실패: $e');
      return null;
    }
  }

  /// Get header row (row 1) to detect column names.
  Future<List<String>?> getSpreadsheetHeaders(String spreadsheetId) async {
    try {
      GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      googleUser ??= await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final headers = await googleUser.authHeaders;
      final client = GoogleAuthClient(headers);
      final sheetsApi = sheets.SheetsApi(client);

      // First get the spreadsheet metadata to find the first sheet name
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
      if (spreadsheet.sheets == null || spreadsheet.sheets!.isEmpty) {
        return null;
      }

      final firstSheetName =
          spreadsheet.sheets!.first.properties?.title ?? 'Sheet1';

      // Get headers from the first sheet
      final result = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        '$firstSheetName!1:1',
      );

      if (result.values == null || result.values!.isEmpty) return null;
      return result.values!.first.map((cell) => cell.toString()).toList();
    } catch (e) {
      debugPrint('스프레드시트 헤더 가져오기 실패: $e');
      return null;
    }
  }

  /// Google Sheets API로 스프레드시트 파일 이름 가져오기
  Future<String?> getSpreadsheetFileName(String spreadsheetId) async {
    try {
      final driveApi = await getDriveApi();
      if (driveApi == null) return null;

      final file =
          await driveApi.files.get(spreadsheetId, $fields: 'name')
              as drive.File;

      return file.name;
    } catch (e) {
      debugPrint('스프레드시트 파일 이름 가져오기 실패: $e');
      return null;
    }
  }

  /// Google Sheets API로 스프레드시트 시트 정보 가져오기
  Future<String?> getFirstSheetName(String spreadsheetId) async {
    try {
      GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      googleUser ??= await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final headers = await googleUser.authHeaders;
      final client = GoogleAuthClient(headers);

      final sheetsApi = sheets.SheetsApi(client);

      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
      if (spreadsheet.sheets != null && spreadsheet.sheets!.isNotEmpty) {
        final sheetName = spreadsheet.sheets!.first.properties?.title;
        debugPrint('시트 이름: $sheetName');
        return sheetName;
      }
      return null;
    } catch (e) {
      debugPrint('시트 이름 가져오기 실패: $e');
      return null;
    }
  }

  /// Google Sheets API로 스프레드시트 셀 업데이트
  Future<void> updateSpreadsheetCell(
    String spreadsheetId,
    String range,
    String value,
  ) async {
    try {
      GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();
      googleUser ??= await _googleSignIn.signIn();
      if (googleUser == null) return;

      final headers = await googleUser.authHeaders;
      final client = GoogleAuthClient(headers);

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

      debugPrint('스프레드시트 업데이트 성공: $range = $value');
    } catch (e) {
      debugPrint('스프레드시트 업데이트 실패: $e');
      rethrow;
    }
  }
}

/// 스프레드시트 파일 정보
class SheetFile {
  final String id;
  final String name;
  final DateTime modifiedTime;
  final List<String>? previewData; // 미리보기 데이터 추가

  SheetFile({
    required this.id,
    required this.name,
    required this.modifiedTime,
    this.previewData,
  });
}

/// 드라이브 아이템 (폴더 또는 파일)
class DriveItem {
  final String id;
  final String name;
  final bool isFolder;
  final bool isSpreadsheet;
  final DateTime modifiedTime;
  final List<String>? previewData; // 미리보기 데이터 추가

  DriveItem({
    required this.id,
    required this.name,
    required this.isFolder,
    required this.isSpreadsheet,
    required this.modifiedTime,
    this.previewData,
  });
}

// 인증 헤더를 http 클라이언트에 입혀주는 도우미 클래스
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
