import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jagadiri/services/google_sheets_service.dart';
import 'package:jagadiri/screens/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final TextEditingController _folderIdController = TextEditingController();
  String? _savedFolderId;

  @override
  void initState() {
    super.initState();
    _loadFolderId();
    // Listen for changes in GoogleSheetsService and navigate if spreadsheetId is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final googleSheetsService = Provider.of<GoogleSheetsService>(context, listen: false);
      if (googleSheetsService.sugarSpreadsheetId != null && googleSheetsService.bpSpreadsheetId != null) {
        _navigateToDashboard();
      }
    });
  }

  @override
  void dispose() {
    _folderIdController.dispose();
    super.dispose();
  }

  Future<void> _loadFolderId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedFolderId = prefs.getString('googleDriveFolderId');
      _folderIdController.text = _savedFolderId ?? '';
    });
  }

  Future<void> _saveFolderId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('googleDriveFolderId', _folderIdController.text);
    setState(() {
      _savedFolderId = _folderIdController.text;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Google Drive Folder ID saved!')),
    );
  }

  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GoogleSheetsService>(
      builder: (context, googleSheetsService, child) {
        // Check if both spreadsheet IDs are available for navigation
        if (googleSheetsService.sugarSpreadsheetId != null && googleSheetsService.bpSpreadsheetId != null) {
          _navigateToDashboard();
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          ); // Show a loading indicator while navigating
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile & Settings'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (googleSheetsService.currentUser == null)
                  Column(
                    children: [
                      const Text('Sign in to connect with Google Drive:'),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () async {
                          await googleSheetsService.signIn();
                        },
                        child: const Text('Sign In with Google'),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Signed in as: \${googleSheetsService.currentUser!.displayName ?? googleSheetsService.currentUser!.email}'),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _folderIdController,
                        decoration: const InputDecoration(
                          labelText: 'Google Drive Folder ID',
                          hintText: 'Enter the ID of your Google Drive folder',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _saveFolderId,
                        child: const Text('Save Folder ID'),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          if (_savedFolderId != null && _savedFolderId!.isNotEmpty) {
                            await googleSheetsService.createAndSetupSpreadsheets(_savedFolderId!); // Pass the folder ID
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a Google Drive Folder ID first.')),
                            );
                          }
                        },
                        child: const Text('Setup Spreadsheets in Google Drive'),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          await googleSheetsService.signOut();
                        },
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
