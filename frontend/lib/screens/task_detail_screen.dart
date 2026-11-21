import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import 'dart:typed_data';

import '../main.dart';
import '../widgets/project_chat_sheet.dart'; // (Pfad beibehalten wie bei dir)
import '../services/auth_service.dart';

import 'package:web/web.dart' as web;

class TaskDetailScreen extends StatefulWidget {
  final Map<String, dynamic> task;
  final Function() onTaskUpdated;
  final int? projectId;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.onTaskUpdated,
    this.projectId,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Map<String, dynamic> _task;
  bool _isEditing = false;
  bool _isSaving = false;
  List<dynamic> _projectUsers = [];
  int? _selectedUserId;

  // Controller für die Textfelder
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _newSubtaskController; // 👈 HIER EINGEFÜGT

  // Lokale Variablen für Dropdowns und Datumswahl
  String _selectedStatus = 'open';
  DateTime? _selectedDueDate;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  @override
  void initState() {
    super.initState();
    _task = Map.from(widget.task);

    _titleController = TextEditingController(text: _task['title'] ?? '');
    _descController = TextEditingController(text: _task['description'] ?? '');
    _newSubtaskController = TextEditingController(); // 👈 HIER INITIALISIERT
    _selectedStatus = _task['status'] ?? 'open';

    _selectedDueDate = _task['due_at'] != null
        ? DateTime.tryParse(_task['due_at'])
        : null;
    _selectedStartDate = _task['planned_start_at'] != null
        ? DateTime.tryParse(_task['planned_start_at'])
        : null;
    _selectedEndDate = _task['planned_end_at'] != null
        ? DateTime.tryParse(_task['planned_end_at'])
        : null;
    _selectedUserId = _task['assigned_user_id'];
    _fetchProjectUsers();
    _fetchTaskDetails();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _newSubtaskController.dispose(); // 👈 HIER FREIGEGEBEN
    super.dispose();
  }

  Future<void> _fetchProjectUsers() async {
    final headers = await AuthService.getHeaders();
    final int? projectId = widget.projectId;

    final String url = projectId != null
        ? '$apiBaseUrl/projects/$projectId/users'
        : '$apiBaseUrl/users';

    try {
      final response = await http.get(Uri.parse(url), headers: headers);

      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _projectUsers = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der User: $e');
    }
  }

  // Methode zum Hinzufügen eines neuen Subtasks
  Future<void> _addSubtask() async {
    final title = _newSubtaskController.text.trim();
    if (title.isEmpty) return;

    final url = Uri.parse('$apiBaseUrl/subtasks');
    try {
      final headers = await AuthService.getHeaders();
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'task_id': widget.task['id'], // Wichtig: Verknüpfung zur Task
          'title': title,
          'is_completed': false,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        _newSubtaskController.clear();
        // Frische die Task-Details auf, damit der neue Subtask sofort angezeigt wird
        await _fetchTaskDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Hinzufügen: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Verbindungsfehler: $e');
    }
  }

  Future<void> _deleteSubtask(int subtaskId) async {
    final url = Uri.parse('$apiBaseUrl/subtasks/$subtaskId');
    final headers = await AuthService.getHeaders();

    try {
      // Wichtig: Hier muss http.delete verwendet werden!
      final response = await http.delete(url, headers: headers);
      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          // Aktualisiert die lokale Subtask-Liste im Task-Detail-Screen sofort
          (_task['subtasks'] as List).removeWhere((s) => s['id'] == subtaskId);
        });

        // Benachrichtigt das übergeordnete Board / den Projekt-Screen, dass sich Daten geändert haben
        widget.onTaskUpdated();

        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Teilpunkt gelöscht')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Löschen: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Verbindungsfehler: $e')));
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    final url = Uri.parse('$apiBaseUrl/tasks/${_task['id']}');
    final headers = await AuthService.getHeaders();

    try {
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode({
          'title': _titleController.text.trim(),
          'description': _descController.text.trim(),
          'status': _selectedStatus,
          'due_at': _selectedDueDate?.toIso8601String(),
          'planned_start_at': _selectedStartDate?.toIso8601String(),
          'planned_end_at': _selectedEndDate?.toIso8601String(),
          'assigned_user_id': _selectedUserId,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          _task['title'] = _titleController.text.trim();
          _task['description'] = _descController.text.trim();
          _task['status'] = _selectedStatus;
          _task['due_at'] = _selectedDueDate?.toIso8601String();
          _task['planned_start_at'] = _selectedStartDate?.toIso8601String();
          _task['planned_end_at'] = _selectedEndDate?.toIso8601String();

          _isEditing = false;
          _isSaving = false;
        });
        widget.onTaskUpdated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erfolgreich gespeichert!')),
        );
      } else {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Speichern: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Verbindungsfehler: $e')));
    }
  }

  Future<void> _uploadAttachment() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      Uint8List fileBytes = result.files.single.bytes!;
      String fileName = result.files.single.name;
      final taskId = _task['id'];

      try {
        final headers = await AuthService.getHeaders();
        headers.remove('Content-Type'); // Wichtig für Multipart

        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$apiBaseUrl/tasks/$taskId/attachments'),
        );
        request.headers.addAll(headers);

        request.files.add(
          http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
        );

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 201) {
          // Backend gibt den neuen Anhang zurück
          final newAttachment = jsonDecode(response.body);

          setState(() {
            // Sicherstellen, dass die Liste existiert, und neuen Anhang hinzufügen
            if (_task['attachments'] == null) {
              _task['attachments'] = [];
            }
            (_task['attachments'] as List).add(newAttachment);
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Datei "$fileName" erfolgreich hochgeladen!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Fehler beim Dateiupload: $e');
      }
    }
  }

  Future<void> _fetchTaskDetails() async {
    // 👇 Nutzt widget.task['id'] statt widget.taskId
    final url = Uri.parse('$apiBaseUrl/tasks/${widget.task['id']}');
    try {
      final headers = await AuthService.getHeaders();
      final response = await http.get(url, headers: headers);
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _task = jsonDecode(response.body);
          // Status und Zuweisung direkt aktualisieren
          _selectedStatus = _task['status'] ?? 'open';
          _selectedUserId = _task['assigned_to_id'];
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Task: $e');
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Nicht gesetzt';
    final date = DateTime.tryParse(dateString);
    if (date == null) return 'Ungültiges Datum';
    return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
  }

  // Widget zur Anzeige der Dateianhänge
  Widget _buildAttachmentsList(List<dynamic> attachments) {
    if (attachments.isEmpty) {
      return const Text(
        'Keine Anhänge vorhanden.',
        style: TextStyle(color: Colors.grey, fontSize: 13),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dateianhänge:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: attachments.length,
          itemBuilder: (context, index) {
            final attachment = attachments[index];
            final fileName = attachment['file_name'] ?? 'Datei';
            final fileUrl =
                'http://127.0.0.1:8000/storage/${attachment['file_path']}';

            return Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                leading: const Icon(
                  Icons.insert_drive_file,
                  color: Colors.blue,
                ),
                title: Text(
                  fileName,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.download, size: 18),
                  onPressed: () {
                    // Moderner Web-Aufruf über package:web
                    web.window.open(fileUrl, '_blank');
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _toggleSubtask(int subtaskId, bool currentStatus) async {
    final url = Uri.parse('$apiBaseUrl/subtasks/$subtaskId');
    try {
      final headers = await AuthService.getHeaders();
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode({'is_completed': !currentStatus}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        await _fetchTaskDetails(); // Lädt die Task-Details neu
      } else {
        debugPrint('Fehler beim Aktualisieren: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Verbindungsfehler: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prüfen, ob wir auf einem PC / breiten Bildschirm sind
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum, color: Colors.blue),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => ChatSheet(
                  targetId: _task['id'],
                  targetType: 'Task',
                  targetName: _task['title'] ?? 'Aufgabe',
                ),
              );
            },
          ),
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
      // 👉 HIER WIRD DER INHALT AUF DEM PC SCHLANK & ZENTRIERT GEHALTEN
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 800 : double.infinity,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TITEL
                _isEditing
                    ? TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Titel',
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : Text(
                        _task['title'] ?? 'Kein Titel',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                const SizedBox(height: 16),

                // 2. STATUS & ZUWEISUNG (Auf PC nebeneinander, mobil untereinander)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 500;
                    final statusWidget = _isEditing
                        ? DropdownButtonFormField<String>(
                            initialValue: _selectedStatus,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'open',
                                child: Text('Offen'),
                              ),
                              DropdownMenuItem(
                                value: 'in_progress',
                                child: Text('In Bearbeitung'),
                              ),
                              DropdownMenuItem(
                                value: 'completed',
                                child: Text('Erledigt'),
                              ),
                              DropdownMenuItem(
                                value: 'closed_incomplete',
                                child: Text('Unvollständig geschlossen'),
                              ),
                            ],
                            onChanged: (val) =>
                                setState(() => _selectedStatus = val!),
                          )
                        : _buildStatusChip(_task['status']);

                    final userWidget = _isEditing
                        ? DropdownButtonFormField<int?>(
                            initialValue:
                                _projectUsers.any(
                                  (u) => u['id'] == _selectedUserId,
                                )
                                ? _selectedUserId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Zugewiesen an',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Niemand'),
                              ),
                              ..._projectUsers.map((user) {
                                return DropdownMenuItem<int?>(
                                  value: user['id'],
                                  child: Text(
                                    user['name'] ?? 'User ${user['id']}',
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) =>
                                setState(() => _selectedUserId = val),
                          )
                        : Row(
                            children: [
                              const Icon(
                                Icons.person,
                                size: 18,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedUserId == null
                                    ? 'Niemand zugewiesen'
                                    : (_projectUsers.firstWhere(
                                            (u) => u['id'] == _selectedUserId,
                                            orElse: () => {
                                              'name': 'Zugewiesen',
                                            },
                                          )['name'] ??
                                          'Zugewiesen'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          );

                    if (isWide && _isEditing) {
                      return Row(
                        children: [
                          Expanded(child: statusWidget),
                          const SizedBox(width: 16),
                          Expanded(child: userWidget),
                        ],
                      );
                    } else {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          statusWidget,
                          const SizedBox(height: 16),
                          userWidget,
                        ],
                      );
                    }
                  },
                ),

                const Divider(height: 32),

                // 3. BESCHREIBUNG
                const Text(
                  'Beschreibung',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                          _task['description'] ??
                              'Keine Beschreibung vorhanden.',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),

                const Divider(height: 32),
                const Divider(height: 32),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dateianhänge',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 1. Der Upload-Button
                    ElevatedButton.icon(
                      onPressed: () async {
                        // ✅ Korrigiert zu _task['id']
                        await _uploadAttachment();
                      },
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Datei hochladen'),
                    ),
                    const SizedBox(height: 12),

                    // 2. Die Liste der Anhänge
                    _buildAttachmentsList(_task['attachments'] ?? []),
                  ],
                ),

                const Divider(height: 32),

                // 4. ZEITANGABEN
                const Text(
                  'Zeitangaben',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),

                _buildInfoRow(
                  Icons.calendar_today,
                  'Erstellt am',
                  _formatDate(_task['created_at']),
                ),

                if (_isEditing)
                  _buildEditableDateRow('Geplanter Start', _selectedStartDate, (
                    newDate,
                  ) {
                    setState(() => _selectedStartDate = newDate);
                  })
                else
                  _buildInfoRow(
                    Icons.play_arrow,
                    'Geplanter Start',
                    _formatDate(_task['planned_start_at']),
                  ),

                if (_isEditing)
                  _buildEditableDateRow('Geplantes Ende', _selectedEndDate, (
                    newDate,
                  ) {
                    setState(() => _selectedEndDate = newDate);
                  })
                else
                  _buildInfoRow(
                    Icons.flag,
                    'Geplantes Ende',
                    _formatDate(_task['planned_end_at']),
                  ),

                if (_isEditing)
                  _buildEditableDateRow('Ablaufdatum (Due)', _selectedDueDate, (
                    newDate,
                  ) {
                    setState(() => _selectedDueDate = newDate);
                  })
                else
                  _buildInfoRow(
                    Icons.warning,
                    'Ablaufdatum (Due)',
                    _formatDate(_task['due_at']),
                    isWarning: true,
                  ),

                const Divider(height: 32),

                // 5. SUBTASKS / TEILPUNKTE
                const Text(
                  'Teilpunkte (Subtasks)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),

                ...(_task['subtasks'] as List? ?? []).map((subtask) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Row(
                      children: [
                        // Checkbox zum Abhaken
                        Checkbox(
                          value: subtask['is_completed'] == true,
                          onChanged: (val) async {
                            if (val != null) {
                              // 1. Lokales UI sofort anpassen
                              setState(() {
                                subtask['is_completed'] = val;
                              });

                              // 2. An das Backend senden (subtask['id'] übergeben)
                              final subId =
                                  int.tryParse(subtask['id'].toString()) ?? 0;
                              if (subId > 0) {
                                // Wir übergeben den vorherigen Status, da deine _toggleSubtask Methode '!currentStatus' rechnet
                                await _toggleSubtask(subId, !val);
                              }
                            }
                          },
                        ),
                        // Subtask Text (durchgestrichen wenn erledigt)
                        Expanded(
                          child: Text(
                            subtask['title'] ?? '',
                            style: TextStyle(
                              decoration: subtask['is_completed'] == true
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: subtask['is_completed'] == true
                                  ? Colors.grey
                                  : Colors.black,
                            ),
                          ),
                        ),
                        // Mülleimer-Button zum Löschen
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () => _deleteSubtask(subtask['id']),
                          tooltip: 'Teilpunkt löschen',
                        ),
                      ],
                    ),
                  );
                }),

                // Eingabefeld für neue Subtasks (bleibt wie gehabt)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newSubtaskController,
                          decoration: const InputDecoration(
                            hintText: 'Neuen Teilpunkt hinzufügen...',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _addSubtask(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle,
                          color: Colors.blue,
                          size: 32,
                        ),
                        onPressed: _addSubtask,
                        tooltip: 'Hinzufügen',
                      ),
                    ],
                  ),
                ),

                const Divider(height: 32),

                // 6. KOMMENTARE
                const Text(
                  'Kommentare',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),

                ChatSheet(
                  targetId: _task['id'],
                  targetType: 'Task',
                  targetName: _task['title'] ?? 'Aufgabe',
                  isEmbedded: true,
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    String label = 'Offen';
    Color color = Colors.blue;
    if (status == 'in_progress') {
      label = 'In Bearbeitung';
      color = Colors.orange;
    } else if (status == 'completed') {
      label = 'Erledigt';
      color = Colors.green;
    } else if (status == 'closed_incomplete') {
      label = 'Unvollständig geschlossen';
      color = Colors.red;
    }

    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isWarning = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: isWarning ? Colors.red : Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isWarning && value != 'Nicht gesetzt'
                  ? Colors.red
                  : Colors.grey.shade800,
              fontWeight: isWarning ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableDateRow(
    String label,
    DateTime? date,
    Function(DateTime?) onDateChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) onDateChanged(picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: label,
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_month),
                  isDense: true,
                ),
                child: Text(
                  date != null
                      ? _formatDate(date.toIso8601String())
                      : 'Nicht gesetzt',
                ),
              ),
            ),
          ),
          if (date != null)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.red),
              onPressed: () => onDateChanged(null),
              tooltip: 'Datum entfernen',
            ),
        ],
      ),
    );
  }
}
