import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../widgets/project_chat_sheet.dart'; // WICHTIG: Importiere das ChatSheet

class TaskDetailScreen extends StatefulWidget {
  final Map<String, dynamic> task;
  final Function() onTaskUpdated;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.onTaskUpdated,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Map<String, dynamic> _task;
  bool _isEditing = false;
  bool _isSaving = false;

  // Controller für die Textfelder
  late TextEditingController _titleController;
  late TextEditingController _descController;

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
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    final url = Uri.parse('$apiBaseUrl/tasks/${_task['id']}');
    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': _titleController.text.trim(),
          'description': _descController.text.trim(),
          'status': _selectedStatus,
          'due_at': _selectedDueDate?.toIso8601String(),
          'planned_start_at': _selectedStartDate?.toIso8601String(),
          'planned_end_at': _selectedEndDate?.toIso8601String(),
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

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Nicht gesetzt';
    final date = DateTime.tryParse(dateString);
    if (date == null) return 'Ungültiges Datum';
    return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Details'),
        actions: [
          // NEU: Der Chat-Button öffnet das wiederverwendbare ChatSheet
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
      body: SingleChildScrollView(
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

            // 2. STATUS
            _isEditing
                ? DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'open', child: Text('Offen')),
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
                    onChanged: (val) => setState(() => _selectedStatus = val!),
                  )
                : _buildStatusChip(_task['status']),

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
                    maxLines: 5,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Beschreibung eingeben...',
                    ),
                  )
                : Text(
                    _task['description'] ?? 'Keine Beschreibung vorhanden.',
                    style: const TextStyle(fontSize: 14),
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

            // 5. ZUWEISUNG
            const Text(
              'Zuweisung',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text('Noch keinem Benutzer zugewiesen (folgt in Phase 4).'),

            const Divider(height: 32),

            // 6. KOMMENTARE (Button zum Öffnen)
            const Text(
              'Kommentare',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            ChatSheet(
              targetId: _task['id'],
              targetType: 'Task',
              targetName: _task['title'] ?? 'Aufgabe',
              isEmbedded: true, // <-- Schaltet den BottomSheet-Modus aus
            ),

            const SizedBox(height: 32), // Platz am Ende
          ],
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
