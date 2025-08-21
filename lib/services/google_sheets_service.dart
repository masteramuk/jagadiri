import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive; // Import Google Drive API
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GoogleSheetsService extends ChangeNotifier {
  GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      sheets.SheetsApi.spreadsheetsScope,
      drive.DriveApi.driveFileScope, // Use driveFileScope for creating/managing files
    ],
  );

  GoogleSignInAccount? _currentUser;
  sheets.SheetsApi? _sheetsApi;
  drive.DriveApi? _driveApi; // Google Drive API instance
  String? _sugarSpreadsheetId;
  String? _bpSpreadsheetId;

  String? get sugarSpreadsheetId => _sugarSpreadsheetId;
  String? get bpSpreadsheetId => _bpSpreadsheetId;
  GoogleSignInAccount? get currentUser => _currentUser;

  Future<void> init() async {
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) async {
      _currentUser = account;
      if (_currentUser != null) {
        await _getApis(); // Initialize both Sheets and Drive APIs
        await _loadSpreadsheetIds();
      } else {
        _sugarSpreadsheetId = null;
        _bpSpreadsheetId = null;
      }
      notifyListeners();
    });
    await _googleSignIn.signInSilently();
  }

  Future<void> signIn() async {
    try {
      await _googleSignIn.signIn();
    } catch (error) {
      print('Error signing in: \$error');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.disconnect();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sugarSpreadsheetId');
    await prefs.remove('bpSpreadsheetId');
    _sugarSpreadsheetId = null;
    _bpSpreadsheetId = null;
    notifyListeners();
  }

  Future<void> _getApis() async {
    if (_currentUser == null) return;

    final authHeaders = await _currentUser!.authHeaders;
    final authenticatedClient = GoogleAuthClient(authHeaders);
    _sheetsApi = sheets.SheetsApi(authenticatedClient);
    _driveApi = drive.DriveApi(authenticatedClient); // Initialize Drive API
  }

  Future<void> _loadSpreadsheetIds() async {
    final prefs = await SharedPreferences.getInstance();
    _sugarSpreadsheetId = prefs.getString('sugarSpreadsheetId');
    _bpSpreadsheetId = prefs.getString('bpSpreadsheetId');
  }

  Future<void> _saveSpreadsheetIds(String sugarId, String bpId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sugarSpreadsheetId', sugarId);
    await prefs.setString('bpSpreadsheetId', bpId);
    _sugarSpreadsheetId = sugarId;
    _bpSpreadsheetId = bpId;
  }

  Future<void> createAndSetupSpreadsheets(String folderId) async {
    if (_sheetsApi == null || _driveApi == null || _currentUser == null) return;

    try {
      // Create Sugar Data Spreadsheet using Drive API
      final sugarFileMetadata = drive.File();
      sugarFileMetadata.name = 'JagaDiri - Sugar Data';
      sugarFileMetadata.parents = [folderId];
      sugarFileMetadata.mimeType = 'application/vnd.google-apps.spreadsheet';

      final sugarDriveFile = await _driveApi!.files.create(sugarFileMetadata);
      final newSugarSpreadsheetId = sugarDriveFile.id;

      // Create BP Data Spreadsheet using Drive API
      final bpFileMetadata = drive.File();
      bpFileMetadata.name = 'JagaDiri - BP & Pulse Data';
      bpFileMetadata.parents = [folderId];
      bpFileMetadata.mimeType = 'application/vnd.google-apps.spreadsheet';

      final bpDriveFile = await _driveApi!.files.create(bpFileMetadata);
      final newBpSpreadsheetId = bpDriveFile.id;

      if (newSugarSpreadsheetId != null && newBpSpreadsheetId != null) {
        await _saveSpreadsheetIds(newSugarSpreadsheetId, newBpSpreadsheetId);
        print('Sugar Spreadsheet created: \${sugarDriveFile.webViewLink}');
        print('BP Spreadsheet created: \${bpDriveFile.webViewLink}');

        // Setup headers for both spreadsheets using Sheets API
        await _writeSugarDataHeaders(newSugarSpreadsheetId);
        await _writeBPDataHeaders(newBpSpreadsheetId);
      }
    } catch (e) {
      print('Error creating or setting up spreadsheets: \$e');
    }
  }

  Future<void> _writeSugarDataHeaders(String spreadsheetId) async {
    final values = [
      ['Date', 'Time', 'Before Breakfast', 'After Breakfast', 'Before Lunch', 'After Lunch', 'Before Dinner', 'After Dinner', 'Before Sleep', 'Status']
    ];
    final valueRange = sheets.ValueRange(values: values);
    try {
      await _sheetsApi!.spreadsheets.values.update(valueRange, spreadsheetId, 'Sheet1!A1', valueInputOption: 'RAW');
    } catch (e) {
      print('Error writing Sugar Data headers: \$e');
    }
  }

  Future<void> _writeBPDataHeaders(String spreadsheetId) async {
    final values = [
      ['Date', 'Time', 'Time Name', 'Systolic', 'Diastolic', 'Pulse Rate', 'Status']
    ];
    final valueRange = sheets.ValueRange(values: values);
    try {
      await _sheetsApi!.spreadsheets.values.update(valueRange, spreadsheetId, 'Sheet1!A1', valueInputOption: 'RAW');
    } catch (e) {
      print('Error writing BP Data headers: \$e');
    }
  }

  // Read data from a sheet
  Future<List<List<Object>>> readData(String spreadsheetId, String range) async {
    if (_sheetsApi == null) {
      await signIn();
      if (_sheetsApi == null) return [];
    }

    try {
      final response = await _sheetsApi!.spreadsheets.values.get(spreadsheetId, range);
      return response.values as List<List<Object>>? ?? [];
    } catch (e) {
      print('Error reading data: \$e');
      return [];
    }
  }

  // Append data to a sheet
  Future<void> appendData(String spreadsheetId, String range, List<List<Object>> values) async {
    if (_sheetsApi == null) {
      await signIn();
      if (_sheetsApi == null) return;
    }

    try {
      final valueRange = sheets.ValueRange();
      valueRange.values = values;
      await _sheetsApi!.spreadsheets.values.append(
        valueRange,
        spreadsheetId,
        range,
        valueInputOption: 'RAW',
      );
      print('Data appended successfully.');
    } catch (e) {
      print('Error appending data: \$e');
    }
  }
}

// Helper class to wrap an authenticated HTTP client
class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}