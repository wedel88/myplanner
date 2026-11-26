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
import '../widgets/inline_editable_text.dart'; // <-- Unser neues Widget
import '../widgets/app_navigation_bar.dart'; // <-- Neue Navigation

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

class _ProjectInfoScreenState extends State<ProjectInfoScreen>
    with WidgetsBindingObserver {
  late Map<String, dynamic> _currentProject;
  List<dynamic> _projectAttachments = [];
  List<dynamic> _userGroups = [];
  List<dynamic> _manageableGroups = [];
  String? _selectedGroupId;

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentProject = Map.from(widget.project);
    _projectAttachments = _currentProject['attachments'] ?? [];
    _selectedGroupId = _currentProject['group_id']?.toString();

    _fetchProjectDetails();
    _fetchUserGroups();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Nicht gesetzt';
    final date = DateTime.tryParse(dateString);
    if (date == null) return 'Ungültiges Datum';
    return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _fetchProjectDetails(silent: true);
    }
  }

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
        final allGroups = jsonDecode(response.body) as List;

        List<dynamic> manageable = [];
        final me = await AuthService.getCurrentUserId();

        for (var group in allGroups) {
          for (var user in (group['users'] ?? [])) {
            if (user['id'] == me) {
              final role = user['pivot']?['role'];
              if (role == 'admin' || role == 'product_owner') {
                manageable.add(group);
              }
              break;
            }
          }
        }

        setState(() {
          _userGroups = allGroups;
          _manageableGroups = manageable;
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Gruppen: $e');
    }
  }

  // Speichert nur ein einzelnes Feld (Titel oder Beschreibung)
  Future<void> _saveField(String field, String newValue) async {
    setState(() => _isSaving = true);
    final headers = await AuthService.getHeaders();

    try {
      final projectId = _currentProject['id'];
      final response = await http.put(
        Uri.parse('${widget.apiBaseUrl}/projects/$projectId'),
        headers: headers,
        body: json.encode({field: newValue}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _currentProject[field] = newValue;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Netzwerkfehler: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Öffnet das Popup zur Gruppenänderung
  void _showGroupSelectionDialog() {
    if (_manageableGroups.isEmpty && _currentProject['group'] != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Du hast keine Berechtigung, die Gruppe zu ändern.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Gruppe zuweisen'),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_off, color: Colors.grey),
                title: const Text('Keine Gruppe'),
                onTap: () {
                  Navigator.pop(context);
                  _updateProjectGroup(null);
                },
              ),
              ..._manageableGroups.map(
                (g) => ListTile(
                  leading: const Icon(Icons.folder, color: Colors.blue),
                  title: Text(g['name']),
                  onTap: () {
                    Navigator.pop(context);
                    _updateProjectGroup(g['id']);
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProjectGroup(int? groupId) async {
    setState(() => _isSaving = true);
    final headers = await AuthService.getHeaders();
    try {
      final response = await http.put(
        Uri.parse('${widget.apiBaseUrl}/projects/${_currentProject['id']}'),
        headers: headers,
        body: json.encode({'group_id': groupId}),
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        _fetchProjectDetails(silent: true); // Im Hintergrund aktualisieren
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gruppe aktualisiert!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Fehler: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
              content: Text('Datei "$fileName" hochgeladen!'),
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
      backgroundColor: Colors.grey.shade50,
      appBar: const AppNavigationBar(
        currentRoute: '/info',
      ), // Navigation einheitlich
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
                      // ==================== PROJEKTNAME & GRUPPE ====================
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: InlineEditableText(
                              initialText:
                                  _currentProject['name'] ?? 'Kein Name',
                              textStyle: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                              onSave: (newName) => _saveField('name', newName),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Gruppen-Badge (klickbar, wenn man Rechte hat)
                          InkWell(
                            onTap: _showGroupSelectionDialog,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _currentProject['group'] != null
                                    ? Colors.blue.shade50
                                    : Colors.grey.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _currentProject['group'] != null
                                      ? Colors.blue.shade100
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _currentProject['group'] != null
                                        ? Icons.group
                                        : Icons.group_off,
                                    size: 14,
                                    color: _currentProject['group'] != null
                                        ? Colors.blue.shade700
                                        : Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _currentProject['group']?['name'] ??
                                        'Keine Gruppe',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _currentProject['group'] != null
                                          ? Colors.blue.shade800
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
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
                      Container(
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: InlineEditableText(
                          initialText: _currentProject['description'] ?? 'Keine Beschreibung vorhanden. (Doppelklicken zum Bearbeiten)',
                          textStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                            height: 1.4,
                          ),
                          maxLines: 4, // Mehrzeilig für Beschreibung
                          onSave: (newDesc) =>
                              _saveField('description', newDesc),
                        ),
                      ),

                      const Divider(height: 40),

                      //========DEADLINE========
                      const SizedBox(height: 24),
                      const Text(
                        'Projekt-Deadline',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _currentProject['due_at'] != null
                                ? DateTime.parse(_currentProject['due_at'])
                                : DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            final headers = await AuthService.getHeaders();
                            await http.put(
                              Uri.parse(
                                '${widget.apiBaseUrl}/projects/${_currentProject['id']}',
                              ),
                              headers: headers,
                              body: json.encode({
                                'due_at': picked.toIso8601String(),
                              }),
                            );
                            _fetchProjectDetails(); // Daten neu laden
                          }
                        },
                        child: Builder(
                          builder: (context) {
                            final dueAtString = _currentProject['due_at'];
                            Color bgColor = Colors.white;
                            Color iconColor = Colors.grey.shade600;
                            Color textColor = Colors.grey.shade800;

                            if (dueAtString != null) {
                              final dueDate = DateTime.parse(dueAtString);
                              final now = DateTime.now();
                              final difference = dueDate.difference(now).inDays;

                              if (difference < 0) {
                                bgColor = Colors.red.shade50;
                                iconColor = Colors.red.shade700;
                                textColor = Colors.red.shade800;
                              } else if (difference <= 14) {
                                bgColor = Colors.orange.shade50;
                                iconColor = Colors.orange.shade800;
                                textColor = Colors.orange.shade900;
                              } else {
                                bgColor = Colors.grey.shade100;
                                iconColor = Colors.grey.shade700;
                                textColor = Colors.grey.shade800;
                              }
                            }

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: dueAtString != null
                                      ? iconColor.withOpacity(0.3)
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    color: iconColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    dueAtString != null
                                        ? _formatDate(dueAtString)
                                        : 'Keine Deadline (Klicken zum Setzen)',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: textColor,
                                      fontWeight: dueAtString != null
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

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
                                      '$storageBaseUrl/${file['file_path']}';
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
                                            ? 'Task: ${taskTitle ?? 'Unbekannt'}'
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
                                        onPressed: () =>
                                            web.window.open(fileUrl, '_blank'),
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
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ChatSheet(
                              targetId: _currentProject['id'],
                              targetType: 'Project',
                              targetName: _currentProject['name'] ?? 'Projekt',
                              isEmbedded: true,
                            ),
                          ),
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
