import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;

import '../main.dart';

class TaskDetailScreen extends StatefulWidget {
  final Map<String, dynamic> task;
  final Function() onTaskUpdated;
  final Function() onEditRequested; // NEU: Callback für den Edit-Button

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.onTaskUpdated,
    required this.onEditRequested, // NEU
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Map<String, dynamic> _task;

  @override
  void initState() {
    super.initState();
    _task = Map.from(widget.task);
  }

  // Hilfsmethode zum Formatieren von Daten
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
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // 1. Wir schließen die Detailansicht
              Navigator.pop(context);
              // 2. Wir rufen das Callback auf, das den Edit-Dialog auf dem Board öffnet
              widget.onEditRequested();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Titel und Status
            Text(
              _task['title'] ?? 'Kein Titel',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildStatusChip(_task['status']),

            const Divider(height: 32),

            // 2. Beschreibung
            const Text(
              'Beschreibung',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              _task['description'] ?? 'Keine Beschreibung vorhanden.',
              style: const TextStyle(fontSize: 14),
            ),

            const Divider(height: 32),

            // 3. Zeitangaben
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
            _buildInfoRow(
              Icons.play_arrow,
              'Geplanter Start',
              _formatDate(_task['planned_start_at']),
            ),
            _buildInfoRow(
              Icons.flag,
              'Geplantes Ende',
              _formatDate(_task['planned_end_at']),
            ),
            _buildInfoRow(
              Icons.warning,
              'Ablaufdatum (Due)',
              _formatDate(_task['due_at']),
              isWarning: true,
            ),

            const Divider(height: 32),

            // 4. Zuweisung (Platzhalter)
            const Text(
              'Zuweisung',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text('Noch keinem Benutzer zugewiesen (folgt in Phase 4).'),
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
}
