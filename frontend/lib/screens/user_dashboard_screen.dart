import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../services/auth_service.dart';
import 'project_detail_screen.dart';
import 'profile_screen.dart';
import 'project_grid_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  bool _isLoading = true;
  List<dynamic> _tasks = [];
  Map<String, dynamic> _stats = {'total': 0, 'completed': 0, 'pending': 0};
  int? _currentUserId; // 👈 ID des eigenen Users für den Filter

  // Filter-Zustände
  String _selectedFilter = 'all'; // 'all', 'pending', 'overdue'
  bool _hideCompleted = true; // Erledigte ausblenden
  bool _onlyMyTasks = false; // 👈 Neuer Schalter: Nur meine Aufgaben

  @override
  void initState() {
    super.initState();
    _loadUserAndDashboardData();
  }

  Future<void> _loadUserAndDashboardData() async {
    final headers = await AuthService.getHeaders();

    try {
      // 1. Eigenen User abrufen, um die ID für den "Nur meine Aufgaben"-Filter zu haben
      final userResponse = await http.get(
        Uri.parse('$apiBaseUrl/me'),
        headers: headers,
      );

      if (userResponse.statusCode == 200) {
        final userData = json.decode(userResponse.body);
        setState(() {
          // Je nachdem, wie dein /me Endpoint das Objekt zurückgibt (z.B. direkt als User oder unter 'user')
          _currentUserId = userData['id'] ?? userData['user']?['id'];
        });
        debugPrint('Eingeloggter User ID ist: $_currentUserId');
      }

      // 2. Dashboard-Daten laden
      final response = await http.get(
        Uri.parse('$apiBaseUrl/dashboard/tasks'),
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
    // Aufgaben filtern basierend auf allen aktivierten Kriterien
    final filteredTasks = _tasks.where((task) {
      final status = task['status'] ?? 'open';
      final assignedUserId = task['assigned_user_id'];

      // 1. "Nur meine Aufgaben"-Filter (Strenge Prüfung!)
      if (_onlyMyTasks) {
        // Wenn dem Task niemand zugewiesen ist (null) ODER die ID nicht zu meinem User passt -> Verstecken!
        if (assignedUserId == null ||
            _currentUserId == null ||
            assignedUserId.toString() != _currentUserId.toString()) {
          return false;
        }
      }

      // 2. Erledigte ausblenden
      if (_hideCompleted && status == 'completed') {
        return false;
      }

      // 3. Status-Filter
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
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_view_rounded),
            tooltip: 'Projekte (Home)',
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProjectGridScreen(),
                ), // Hier den echten Klassennamen einsetzen!
                (route) => false,
              );
            },
          ),
          // 3. Zum Profil wechseln
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Mein Profil',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
            onPressed: () {
              setState(() => _isLoading = true);
              _loadUserAndDashboardData();
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStatCard(
                        'Heute erledigt',
                        '${_stats['completed_today'] ?? 0}',
                        Colors.teal,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'Letzte 7 Tage',
                        '${_stats['completed_week'] ?? 0}',
                        Colors.indigo,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'Diesen Monat',
                        '${_stats['completed_month'] ?? 0}',
                        Colors.purple,
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
                      // 👉 NEU: Zuweisungs-Filter (Alle vs. Nur meine)
                      ChoiceChip(
                        label: const Text('Alle Aufgaben'),
                        selected: !_onlyMyTasks,
                        onSelected: (selected) =>
                            setState(() => _onlyMyTasks = false),
                      ),
                      ChoiceChip(
                        label: const Text('👤 Nur meine Aufgaben'),
                        selected: _onlyMyTasks,
                        onSelected: (selected) =>
                            setState(() => _onlyMyTasks = true),
                      ),
                      const SizedBox(width: 8),

                      // Status-Filter
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
                      const SizedBox(width: 8),

                      // Erledigte ausblenden
                      FilterChip(
                        label: const Text('Erledigte ausblenden'),
                        selected: _hideCompleted,
                        onSelected: (val) =>
                            setState(() => _hideCompleted = val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(
                    _onlyMyTasks
                        ? 'Deine persönlichen Aufgaben'
                        : 'Alle Projekt-Aufgaben im Team',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
