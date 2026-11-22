import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

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

// 👈 1. Mit 'WidgetsBindingObserver' erweitern, um App-Zustände (Vordergrund/Hintergrund) zu erkennen
class _ProjectInfoScreenState extends State<ProjectInfoScreen>
    with WidgetsBindingObserver {
  late Map<String, dynamic> _currentProject;
  List<dynamic> _projectAttachments = [];
  List<dynamic> _userGroups = [];
  String? _selectedGroupId;

  bool _isLoading = false;
  bool _isEditing = false;
  bool _isSaving = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 👈 Observer registrieren
    _currentProject = Map.from(widget.project);
    _projectAttachments = _currentProject['attachments'] ?? [];

    _nameController.text = _currentProject['name'] ?? '';
    _descController.text = _currentProject['description'] ?? '';

    _fetchProjectDetails();
    _fetchUserGroups();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(
      this,
    ); // 👈 Observer sauber entfernen
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // 👇 2. Automatisch im Hintergrund triggern, wenn die App/der Screen wieder aktiv wird
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Wenn der Nutzer z. B. aus dem Browser/Hintergrund zurückkehrt
      _fetchProjectDetails(silent: true);
    }
  }

  // 👈 Optional ein 'silent' Parameter, damit bei Hintergrund-Updates nicht der große Lade-Kreis angezeigt wird
  Future<void> _fetchProjectDetails({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _isLoading = true);

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
          _selectedGroupId = data['group_id']?.toString();
          _isLoading = false;
        });
      } else {
        if (!silent) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Projektdetails: $e');
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUserGroups() async {
    final headers = await AuthService.getHeaders();
    try {
      final response = await http.get(
        Uri.parse('${widget.apiBaseUrl}/groups'),
        headers: headers,
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _userGroups = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Gruppen: $e');
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    final headers = await AuthService.getHeaders();
    try {
      final projectId = _currentProject['id'];

      final response = await http.put(
        Uri.parse('${widget.apiBaseUrl}/projects/$projectId'),
        headers: headers,
        body: json.encode({
          'name': _nameController.text.trim(),
          'description': _descController.text.trim(),
          'group_id': _selectedGroupId != null
              ? int.parse(_selectedGroupId!)
              : null,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Finde den Namen der ausgewählten Gruppe für die sofortige lokale Anzeige heraus
        String? groupName;
        if (_selectedGroupId != null) {
          final foundGroup = _userGroups.firstWhere(
            (g) => g['id'].toString() == _selectedGroupId,
            orElse: () => null,
          );
          if (foundGroup != null) {
            groupName = foundGroup['name'];
          }
        }

        setState(() {
          _isEditing = false;
          // Aktualisiere Name und Beschreibung lokal
          _currentProject['name'] = _nameController.text.trim();
          _currentProject['description'] = _descController.text.trim();
          _currentProject['group_id'] = _selectedGroupId != null
              ? int.parse(_selectedGroupId!)
              : null;

          // Setze oder lösche die 'group'-Relation sofort lokal, damit das Badge direkt bleibt!
          if (_selectedGroupId != null && groupName != null) {
            _currentProject['group'] = {
              'id': int.parse(_selectedGroupId!),
              'name': groupName,
            };
          } else {
            _currentProject['group'] = null;
          }
        });

        // Optional im Hintergrund frisch von der API laden lassen
        _fetchProjectDetails(silent: true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Änderungen erfolgreich gespeichert!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Verbindungsfehler: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Netzwerkfehler: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    List<dynamic> allFiles = [..._projectAttachments];

    if (_currentProject['containers'] != null) {
      for (var container in _currentProject['containers']) {
        if (container['tasks'] != null) {
          for (var task in container['tasks']) {
            if (task['attachments'] != null) {
              for (var att in task['attachments']) {
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
        elevation: 0,
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
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ==================== PROJEKTNAME & GRUPPE (MODERN HEADER) ====================
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Linke Seite: Projektname
                          Expanded(
                            child: _isEditing
                                ? TextField(
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                      labelText: 'Projektname',
                                      filled: true,
                                      fillColor: Colors.grey.withOpacity(0.04),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: Colors.blue,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : Text(
                                    _currentProject['name'] ?? 'Kein Name',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                        ),
                                  ),
                          ),
                          const SizedBox(width: 16),

                          // Rechte Seite: Gruppe (Dropdown im Edit-Mode, Badge oder Hinweis im View-Mode)
                          if (_isEditing)
                            SizedBox(
                              width: 220,
                              child: DropdownButtonFormField<String>(
                                value: _selectedGroupId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Gruppe',
                                  filled: true,
                                  fillColor: Colors.grey.withOpacity(0.04),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(
                                      'Keine Gruppe',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  ..._userGroups.map((group) {
                                    return DropdownMenuItem<String>(
                                      value: group['id'].toString(),
                                      child: Text(
                                        group['name'],
                                        style: const TextStyle(fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _selectedGroupId = value;
                                  });
                                },
                              ),
                            )
                          else
                            // 👈 NEU: Unterscheidung, ob Gruppe vorhanden oder nicht
                            _currentProject['group'] != null
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.blue.shade100,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.group,
                                          size: 14,
                                          color: Colors.blue.shade700,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _currentProject['group']['name'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Text(
                                      'Keine Gruppe zugewiesen',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ==================== BESCHREIBUNG ====================
                      const Text(
                        'Projektbeschreibung',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _isEditing
                          ? TextField(
                              controller: _descController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: 'Beschreibung eingeben...',
                                filled: true,
                                fillColor: Colors.grey.withOpacity(0.04),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.blue,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.all(16),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Text(
                                _currentProject['description'] ??
                                    'Keine Beschreibung vorhanden.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                  height: 1.4,
                                ),
                              ),
                            ),

                      const Divider(height: 40),

                      // ==================== DATEIANHÄNGE ====================
                      const Text(
                        'Dateianhänge (Projekt & Tasks)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _uploadProjectFile,
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text('Datei hochladen'),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade200),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.delete_sweep, size: 16),
                            label: const Text('Verwalten / Löschen'),
                            onPressed: () async {
                              await showDialog(
                                context: context,
                                builder: (context) => ProjectFilesDialog(
                                  projectId: _currentProject['id'],
                                  projectName:
                                      _currentProject['name'] ?? 'Projekt',
                                ),
                              );
                              _fetchProjectDetails(silent: true);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      allFiles.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'Keine Dateien vorhanden.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          : SizedBox(
                              height: 200,
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
                                    elevation: 0,
                                    margin: const EdgeInsets.only(bottom: 6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: ListTile(
                                      dense: true,
                                      leading: Icon(
                                        isTaskFile
                                            ? Icons.task
                                            : Icons.insert_drive_file,
                                        color: isTaskFile
                                            ? Colors.orange.shade700
                                            : Colors.blue.shade700,
                                      ),
                                      title: Text(
                                        fileName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
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

                      const Divider(height: 40),

                      // ==================== PROJEKT-CHAT ====================
                      const Text(
                        'Projekt-Chat',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
