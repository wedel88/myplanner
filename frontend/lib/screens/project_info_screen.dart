import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import '../main.dart';
import '../services/auth_service.dart';
import '../widgets/project_chat_sheet.dart';
import '../widgets/project_files_dialog.dart';

class ProjectInfoScreen extends StatefulWidget {
  final Map<String, dynamic> project;
  final String apiBaseUrl;

  const ProjectInfoScreen({
    super.key,
    required this.project,
    required this.apiBaseUrl,
  });

  @override
  State<ProjectInfoScreen> createState() => _ProjectInfoScreenState();
}

class _ProjectInfoScreenState extends State<ProjectInfoScreen> {
  late Map<String, dynamic> _currentProject;
  List<dynamic> _projectAttachments = [];

  bool _isLoading = false;
  bool _isEditing = false;
  bool _isSaving = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentProject = Map.from(widget.project);
    _projectAttachments = _currentProject['attachments'] ?? [];

    _nameController.text = _currentProject['name'] ?? '';
    _descController.text = _currentProject['description'] ?? '';

    _fetchProjectDetails();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _fetchProjectDetails() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final headers = await AuthService.getHeaders();
      final projectId = _currentProject['id'];

      final response = await http.get(
        Uri.parse('${widget.apiBaseUrl}/projects/$projectId'),
        headers: headers,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _currentProject = data;
          _projectAttachments = data['attachments'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Projektdetails: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final headers = await AuthService.getHeaders();
      final projectId = _currentProject['id'];

      final response = await http.put(
        Uri.parse('${widget.apiBaseUrl}/projects/$projectId'),
        headers: headers,
        body: json.encode({
          'name': _nameController.text.trim(),
          'description': _descController.text.trim(),
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          _currentProject['name'] = _nameController.text.trim();
          _currentProject['description'] = _descController.text.trim();
          _isEditing = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Projekt erfolgreich aktualisiert!')),
        );
      } else {
        setState(() => _isSaving = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      debugPrint('Fehler beim Speichern: $e');
    }
  }

  // 📂 Web-kompatibler Datei-Upload (Projektweit)
  Future<void> _uploadProjectFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      Uint8List fileBytes = result.files.single.bytes!;
      String fileName = result.files.single.name;
      final projectId = _currentProject['id'];

      try {
        final headers = await AuthService.getHeaders();
        headers.remove('Content-Type');

        var request = http.MultipartRequest(
          'POST',
          Uri.parse('${widget.apiBaseUrl}/projects/$projectId/attachments'),
        );
        request.headers.addAll(headers);
        request.files.add(
          http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
        );

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (!mounted) return;

        if (response.statusCode == 201) {
          await _fetchProjectDetails();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Datei "$fileName" erfolgreich hochgeladen!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Upload-Fehler: $e');
      }
    }
  }

  // 📎 Datei direkt aus dem Chat-Bereich hochladen
  Future<void> _uploadChatFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      Uint8List fileBytes = result.files.single.bytes!;
      String fileName = result.files.single.name;
      final projectId = _currentProject['id'];

      try {
        final headers = await AuthService.getHeaders();
        headers.remove('Content-Type');

        var request = http.MultipartRequest(
          'POST',
          Uri.parse('${widget.apiBaseUrl}/projects/$projectId/attachments'),
        );
        request.headers.addAll(headers);

        if (_chatController.text.trim().isNotEmpty) {
          request.fields['content'] = _chatController.text.trim();
        }

        request.files.add(
          http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
        );

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (!mounted) return;

        if (response.statusCode == 201) {
          _chatController.clear();
          await _fetchProjectDetails();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Datei "$fileName" im Chat geteilt!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Chat-Upload-Fehler: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    // Alle Anhänge sammeln (Projekt-Anhänge + Task-Anhänge aus den Containern)
    List<dynamic> allFiles = [..._projectAttachments];

    if (_currentProject['containers'] != null) {
      for (var container in _currentProject['containers']) {
        if (container['tasks'] != null) {
          for (var task in container['tasks']) {
            if (task['attachments'] != null) {
              for (var att in task['attachments']) {
                // Task-Namen für die Anzeige im UI anhängen
                att['task_title'] = task['title'] ?? 'Aufgabe';
                allFiles.add(att);
              }
            }
          }
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentProject['name'] ?? 'Projekt-Info'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_isEditing)
            IconButton(
              icon: const Icon(Icons.save, color: Colors.green),
              onPressed: _saveChanges,
              tooltip: 'Speichern',
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Bearbeiten',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 800 : double.infinity,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. PROJEKTNAME
                      _isEditing
                          ? TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Projektname',
                                border: OutlineInputBorder(),
                              ),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : Text(
                              _currentProject['name'] ?? 'Kein Name',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                      const SizedBox(height: 16),

                      // 2. BESCHREIBUNG
                      const Text(
                        'Projektbeschreibung',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _isEditing
                          ? TextField(
                              controller: _descController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Beschreibung eingeben...',
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.all(12),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _currentProject['description'] ??
                                    'Keine Beschreibung vorhanden.',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),

                      const Divider(height: 32),

                      // 3. DATEIANHÄNGE (Scrollbar mit Max-Höhe)
                      const Text(
                        'Dateianhänge (Projekt & Tasks)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _uploadProjectFile,
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: const Text('Projektweite Datei hochladen'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.redAccent),
                        ),
                        icon: const Icon(Icons.delete_sweep, size: 16),
                        label: const Text('Dateien verwalten / löschen'),
                        onPressed: () {
                          // 👇 Korrigiert: Nutzt _currentProject['id'] und _currentProject['name']
                          showDialog(
                            context: context,
                            builder: (context) => ProjectFilesDialog(
                              projectId: _currentProject['id'],
                              projectName: _currentProject['name'] ?? 'Projekt',
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      allFiles.isEmpty
                          ? const Text(
                              'Keine Dateien vorhanden.',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            )
                          : SizedBox(
                              height: 220,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: allFiles.length,
                                itemBuilder: (context, index) {
                                  final file = allFiles[index];
                                  final fileName = file['file_name'] ?? 'Datei';
                                  final fileUrl =
                                      'http://127.0.0.1:8000/storage/${file['file_path']}';
                                  final isTaskFile = file['task_id'] != null;
                                  final taskTitle = file['task_title'];

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    child: ListTile(
                                      dense: true,
                                      leading: Icon(
                                        isTaskFile
                                            ? Icons.task
                                            : Icons.insert_drive_file,
                                        color: isTaskFile
                                            ? Colors.orange
                                            : Colors.blue,
                                      ),
                                      title: Text(
                                        fileName,
                                        style: const TextStyle(fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        isTaskFile
                                            ? 'Task: ${taskTitle ?? 'Unbekannte Aufgabe'}'
                                            : 'Projektweite Datei',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.download,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          web.window.open(fileUrl, '_blank');
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                      const Divider(height: 32),

                      // 4. EINGEBETTETER PROJEKT-CHAT (Mit Upload-Option)
                      const Text(
                        'Projekt-Chat',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 400,
                        child: Stack(
                          children: [
                            ChatSheet(
                              targetId: _currentProject['id'],
                              targetType: 'Project',
                              targetName: _currentProject['name'] ?? 'Projekt',
                              isEmbedded: true,
                            ),
                          ],
                        ),
                      ),

                      // Zusätzlicher Upload-Button für den Chat
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: OutlinedButton.icon(
                          onPressed: _uploadChatFile,
                          icon: const Icon(Icons.attach_file, size: 18),
                          label: const Text('Datei im Chat hochladen'),
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
