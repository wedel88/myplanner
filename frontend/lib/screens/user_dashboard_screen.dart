import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import 'project_detail_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  bool _isLoading = true;
  List<dynamic> _tasks = [];
  Map<String, dynamic> _stats = {'total': 0, 'completed': 0, 'pending': 0};

  // Filter-Zustände
  String _selectedFilter = 'all'; // 'all', 'pending', 'overdue'
  bool _hideCompleted = true; // Erledigte ausblenden

  final String baseUrl = 'http://127.0.0.1:8000/api';

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    final headers = await AuthService.getHeaders();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/dashboard/tasks'),
        headers: headers,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _tasks = data['tasks'] ?? [];
          _stats = data['stats'] ?? {'total': 0, 'completed': 0, 'pending': 0};
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // Hilfsfunktion für einheitliche Status-Farben
  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'open':
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'completed':
        return 'Erledigt';
      case 'in_progress':
        return 'In Bearbeitung';
      case 'open':
      default:
        return 'Offen';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Aufgaben filtern basierend auf dem ausgewählten Filter und dem "Erledigte ausblenden"-Schalter
    final filteredTasks = _tasks.where((task) {
      final status = task['status'] ?? 'open';

      // 1. Erledigte ausblenden
      if (_hideCompleted && status == 'completed') {
        return false;
      }

      // 2. Filter anwenden
      if (_selectedFilter == 'pending') {
        return status != 'completed';
      } else if (_selectedFilter == 'overdue') {
        if (task['due_at'] == null) return false;
        final dueDate = DateTime.parse(task['due_at']);
        return dueDate.isBefore(DateTime.now()) && status != 'completed';
      }

      return true; // 'all'
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mein Dashboard'),
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchDashboardData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Statistik-Karten oben
                  Row(
                    children: [
                      _buildStatCard(
                        'Gesamt',
                        '${_stats['total']}',
                        Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'Offen',
                        '${_stats['pending']}',
                        Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'Erledigt',
                        '${_stats['completed']}',
                        Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Filter-Leiste & Schalter
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ChoiceChip(
                        label: const Text('Alle'),
                        selected: _selectedFilter == 'all',
                        onSelected: (selected) =>
                            setState(() => _selectedFilter = 'all'),
                      ),
                      ChoiceChip(
                        label: const Text('Offen & Aktiv'),
                        selected: _selectedFilter == 'pending',
                        onSelected: (selected) =>
                            setState(() => _selectedFilter = 'pending'),
                      ),
                      ChoiceChip(
                        label: const Text('Überfällig ⚠️'),
                        selected: _selectedFilter == 'overdue',
                        onSelected: (selected) =>
                            setState(() => _selectedFilter = 'overdue'),
                      ),
                      const VerticalDivider(),
                      FilterChip(
                        label: const Text('Erledigte ausblenden'),
                        selected: _hideCompleted,
                        onSelected: (val) =>
                            setState(() => _hideCompleted = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Deine zugewiesenen Aufgaben',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Aufgaben-Liste
                  Expanded(
                    child: filteredTasks.isEmpty
                        ? const Center(
                            child: Text(
                              'Keine Aufgaben in dieser Ansicht gefunden.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredTasks.length,
                            itemBuilder: (context, index) {
                              final task = filteredTasks[index];
                              final projectName =
                                  task['container']?['project']?['name'] ??
                                  'Unbekanntes Projekt';
                              final projectId =
                                  task['container']?['project']?['id'];
                              final status = task['status'] ?? 'open';
                              final dueAt = task['due_at'];

                              // Prüfen ob überfällig
                              bool isOverdue = false;
                              if (dueAt != null && status != 'completed') {
                                final dueDate = DateTime.parse(dueAt);
                                isOverdue = dueDate.isBefore(DateTime.now());
                              }

                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  onTap: () {
                                    if (projectId != null) {
                                      // Klick führt direkt ins jeweilige Projekt-Board!
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProjectDetailScreen(
                                            projectId: projectId,
                                            projectName: projectName,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  title: Text(
                                    task['title'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        '📁 Projekt: $projectName',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      if (dueAt != null) ...[
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              size: 14,
                                              color: isOverdue
                                                  ? Colors.red
                                                  : Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Fällig: ${dueAt.toString().substring(0, 10)}',
                                              style: TextStyle(
                                                color: isOverdue
                                                    ? Colors.red
                                                    : Colors.grey.shade600,
                                                fontWeight: isOverdue
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _getStatusColor(status),
                                      ),
                                    ),
                                    child: Text(
                                      _getStatusText(status),
                                      style: TextStyle(
                                        color: _getStatusColor(status),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
