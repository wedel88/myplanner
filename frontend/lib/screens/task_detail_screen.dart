import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../main.dart';
import '../widgets/project_chat_sheet.dart';
import '../services/auth_service.dart';

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
  late TextEditingController _newSubtaskController;

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
    _newSubtaskController = TextEditingController();
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
    _newSubtaskController.dispose();
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
          'task_id': widget.task['id'],
          'title': title,
          'is_completed': false,
        }),
      );

      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        _newSubtaskController.clear();
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
      final response = await http.delete(url, headers: headers);
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          (_task['subtasks'] as List).removeWhere((s) => s['id'] == subtaskId);
        });
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
        headers.remove('Content-Type');

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
          final newAttachment = jsonDecode(response.body);
          setState(() {
            if (_task['attachments'] == null) _task['attachments'] = [];
            (_task['attachments'] as List).add(newAttachment);
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Datei "$fileName" hochgeladen!'),
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
    final url = Uri.parse('$apiBaseUrl/tasks/${widget.task['id']}');
    try {
      final headers = await AuthService.getHeaders();
      final response = await http.get(url, headers: headers);
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _task = jsonDecode(response.body);
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
        await _fetchTaskDetails();
      }
    } catch (e) {
      debugPrint('Verbindungsfehler: $e');
    }
  }

  // --- DESIGN BAUSTEINE ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.withOpacity(0.04),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isWarning = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isWarning ? Colors.red : Colors.grey.shade600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isWarning ? Colors.red : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableDateRow(
    String label,
    DateTime? currentDate,
    Function(DateTime?) onDateChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: currentDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) onDateChanged(picked);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    currentDate != null
                        ? _formatDate(currentDate.toIso8601String())
                        : 'Datum wählen',
                    style: TextStyle(
                      fontSize: 13,
                      color: currentDate != null
                          ? Colors.black87
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) widget.onTaskUpdated();
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50, // Leichter Hintergrund
        appBar: AppBar(
          title: const Text(
            'Task Details',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          actions: [
            IconButton(
              icon: const Icon(Icons.forum, color: Colors.blue),
              tooltip: 'Kommentare',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
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
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 800 : double.infinity,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==================== 1. HEADER: TITEL & STATUS ====================
                  if (_isEditing)
                    _buildStyledTextField(
                      controller: _titleController,
                      label: 'Task Titel',
                    )
                  else
                    Text(
                      _task['title'] ?? 'Kein Titel',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                    ),

                  const SizedBox(height: 16),

                  // STATUS & ZUWEISUNG
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 500;
                      final statusWidget = _isEditing
                          ? DropdownButtonFormField<String>(
                              value: _selectedStatus,
                              decoration: InputDecoration(
                                labelText: 'Status',
                                filled: true,
                                fillColor: Colors.grey.withOpacity(0.04),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
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
                              value:
                                  _projectUsers.any(
                                    (u) => u['id'] == _selectedUserId,
                                  )
                                  ? _selectedUserId
                                  : null,
                              decoration: InputDecoration(
                                labelText: 'Zugewiesen an',
                                filled: true,
                                fillColor: Colors.grey.withOpacity(0.04),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
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
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Niemand'),
                                ),
                                ..._projectUsers.map(
                                  (user) => DropdownMenuItem<int?>(
                                    value: user['id'],
                                    child: Text(user['name'] ?? 'User'),
                                  ),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _selectedUserId = val),
                            )
                          : _buildAssigneeChip();

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
                            const SizedBox(height: 12),
                            userWidget,
                          ],
                        );
                      }
                    },
                  ),

                  const Divider(height: 40, color: Colors.transparent),

                  // ==================== 2. BESCHREIBUNG ====================
                  _buildSectionTitle('Beschreibung'),
                  _isEditing
                      ? _buildStyledTextField(
                          controller: _descController,
                          label: 'Beschreibung',
                          maxLines: 5,
                          hint: 'Beschreibung eingeben...',
                        )
                      : Container(
                          padding: const EdgeInsets.all(16),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            _task['description'] ??
                                'Keine Beschreibung vorhanden.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                              height: 1.5,
                            ),
                          ),
                        ),

                  const Divider(height: 40, color: Colors.transparent),

                  // ==================== 3. ZEITANGABEN ====================
                  _buildSectionTitle('Zeitangaben'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          Icons.calendar_today,
                          'Erstellt am',
                          _formatDate(_task['created_at']),
                        ),
                        const Divider(height: 20),
                        if (_isEditing)
                          _buildEditableDateRow(
                            'Geplanter Start',
                            _selectedStartDate,
                            (newDate) =>
                                setState(() => _selectedStartDate = newDate),
                          )
                        else
                          _buildInfoRow(
                            Icons.play_arrow,
                            'Geplanter Start',
                            _formatDate(_task['planned_start_at']),
                          ),
                        const Divider(height: 20),
                        if (_isEditing)
                          _buildEditableDateRow(
                            'Geplantes Ende',
                            _selectedEndDate,
                            (newDate) =>
                                setState(() => _selectedEndDate = newDate),
                          )
                        else
                          _buildInfoRow(
                            Icons.flag,
                            'Geplantes Ende',
                            _formatDate(_task['planned_end_at']),
                          ),
                        const Divider(height: 20),
                        if (_isEditing)
                          _buildEditableDateRow(
                            'Ablaufdatum (Due)',
                            _selectedDueDate,
                            (newDate) =>
                                setState(() => _selectedDueDate = newDate),
                          )
                        else
                          _buildInfoRow(
                            Icons.warning_amber_rounded,
                            'Ablaufdatum (Due)',
                            _formatDate(_task['due_at']),
                            isWarning: true,
                          ),
                      ],
                    ),
                  ),

                  const Divider(height: 40, color: Colors.transparent),

                  // ==================== 4. SUBTASKS ====================
                  _buildSectionTitle('Teilpunkte (Subtasks)'),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        ...(_task['subtasks'] as List? ?? []).map((subtask) {
                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 4.0,
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: subtask['is_completed'] == true,
                                      activeColor: Colors.blue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      onChanged: (val) async {
                                        if (val != null) {
                                          setState(
                                            () => subtask['is_completed'] = val,
                                          );
                                          final subId =
                                              int.tryParse(
                                                subtask['id'].toString(),
                                              ) ??
                                              0;
                                          if (subId > 0)
                                            await _toggleSubtask(subId, !val);
                                        }
                                      },
                                    ),
                                    Expanded(
                                      child: Text(
                                        subtask['title'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          decoration:
                                              subtask['is_completed'] == true
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: subtask['is_completed'] == true
                                              ? Colors.grey
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          _deleteSubtask(subtask['id']),
                                      tooltip: 'Löschen',
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                            ],
                          );
                        }),
                        // Eingabefeld für neuen Subtask
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _newSubtaskController,
                                  style: const TextStyle(fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Neuen Teilpunkt hinzufügen...',
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.grey.withOpacity(0.04),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onSubmitted: (_) => _addSubtask(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: Colors.blue,
                                  size: 28,
                                ),
                                onPressed: _addSubtask,
                                tooltip: 'Hinzufügen',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 40, color: Colors.transparent),

                  // ==================== 5. DATEIANHÄNGE ====================
                  _buildSectionTitle('Dateianhänge'),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _uploadAttachment,
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: const Text('Datei hochladen'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child:
                        (_task['attachments'] == null ||
                            (_task['attachments'] as List).isEmpty)
                        ? Text(
                            'Keine Dateien vorhanden.',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : Column(
                            children: (_task['attachments'] as List).map((
                              attachment,
                            ) {
                              final fileName =
                                  attachment['file_name'] ?? 'Datei';
                              final fileUrl =
                                  'http://127.0.0.1:8000/storage/${attachment['file_path']}';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.insert_drive_file,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        fileName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.download,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                      onPressed: () =>
                                          web.window.open(fileUrl, '_blank'),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),

                  const Divider(height: 40, color: Colors.transparent),

                  // ==================== 6. KOMMENTARE ====================
                  _buildSectionTitle('Kommentare'),
                  Container(
                    height: 400,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ChatSheet(
                        targetId: _task['id'],
                        targetType: 'Task',
                        targetName: _task['title'] ?? 'Aufgabe',
                        isEmbedded: true,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS FÜR BADGES ---

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
      label = 'Unvollständig';
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssigneeChip() {
    String name = 'Niemand zugewiesen';
    if (_selectedUserId != null) {
      final user = _projectUsers.firstWhere(
        (u) => u['id'] == _selectedUserId,
        orElse: () => null,
      );
      if (user != null) name = user['name'];
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person, size: 16, color: Colors.black54),
          const SizedBox(width: 6),
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
