import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import '../main.dart';
import '../services/auth_service.dart';

class ProjectFilesDialog extends StatefulWidget {
  final int projectId;
  final String projectName;

  const ProjectFilesDialog({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ProjectFilesDialog> createState() => _ProjectFilesDialogState();
}

class _ProjectFilesDialogState extends State<ProjectFilesDialog> {
  List<dynamic> _files = [];
  bool _isLoading = true;
  final Set<int> _selectedFileIds = {};

  @override
  void initState() {
    super.initState();
    _fetchProjectFiles();
  }

  // 🔄 Lädt die Dateien im Hintergrund neu
  Future<void> _fetchProjectFiles() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final url = Uri.parse('$apiBaseUrl/projects/${widget.projectId}/files');
    debugPrint('Lade Dateien von: $url');

    try {
      final headers = await AuthService.getHeaders();
      final response = await http.get(url, headers: headers);

      debugPrint('Statuscode Dateien: ${response.statusCode}');
      debugPrint('Response Body Dateien: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _files = jsonDecode(response.body);
          _selectedFileIds.clear();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Dateien: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // 🗑️ Einzelne Datei löschen und direkt Hintergrund-Refresh triggern
  Future<void> _deleteFile(int fileId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Datei löschen?'),
        content: const Text(
          'Möchtest du diese Datei wirklich endgültig löschen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final url = Uri.parse('$apiBaseUrl/attachments/$fileId');
      try {
        final headers = await AuthService.getHeaders();
        final response = await http.delete(url, headers: headers);

        if (!mounted) return;
        if (response.statusCode == 200 || response.statusCode == 204) {
          // 👇 Automatischer Refresh im Hintergrund nach dem Löschen
          await _fetchProjectFiles();
        }
      } catch (e) {
        debugPrint('Fehler beim Löschen der Datei: $e');
      }
    }
  }

  // 🗑️ Mehrere Dateien gleichzeitig löschen und Hintergrund-Refresh triggern
  Future<void> _deleteSelectedFiles() async {
    if (_selectedFileIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ausgewählte Dateien löschen?'),
        content: Text(
          'Möchtest du wirklich ${_selectedFileIds.length} Dateien endgültig löschen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Alle löschen',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final headers = await AuthService.getHeaders();
        for (var id in _selectedFileIds) {
          await http.delete(
            Uri.parse('$apiBaseUrl/attachments/$id'),
            headers: headers,
          );
        }

        if (!mounted) return;
        // 👇 Automatischer Refresh im Hintergrund nach dem Massenlöschen
        await _fetchProjectFiles();
      } catch (e) {
        debugPrint('Fehler beim Massenlöschen: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              'Dateien in ${widget.projectName}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          if (_selectedFileIds.isNotEmpty)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              icon: const Icon(Icons.delete, size: 16),
              label: Text('${_selectedFileIds.length} löschen'),
              onPressed: _deleteSelectedFiles,
            ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 450,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _files.isEmpty
            ? const Center(
                child: Text('Keine Dateien in diesem Projekt vorhanden.'),
              )
            : ListView.builder(
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final file = _files[index];
                  final fileId = file['id'];
                  final fileName = file['file_name'] ?? 'Unbekannte Datei';
                  final filePath = file['file_path'] ?? '';
                  final isTaskFile = file['task_id'] != null;
                  final ownerName = file['user']?['name'] ?? 'Unbekannt';
                  final isSelected = _selectedFileIds.contains(fileId);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedFileIds.add(fileId);
                        } else {
                          _selectedFileIds.remove(fileId);
                        }
                      });
                    },
                    title: Row(
                      children: [
                        Icon(
                          isTaskFile ? Icons.task : Icons.insert_drive_file,
                          color: isTaskFile ? Colors.orange : Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fileName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(left: 28.0, top: 4.0),
                      child: Text(
                        isTaskFile
                            ? 'Task #${file['task_id']} • Hochgeladen von $ownerName'
                            : 'Projektweit • Hochgeladen von $ownerName',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    secondary: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.download,
                            color: Colors.green,
                            size: 20,
                          ),
                          tooltip: 'Herunterladen',
                          onPressed: () {
                            final fileUrl =
                                'http://127.0.0.1:8000/storage/$filePath';
                            web.window.open(fileUrl, '_blank');
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          tooltip: 'Löschen',
                          onPressed: () => _deleteFile(fileId),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Schließen'),
        ),
      ],
    );
  }
}
