import 'package:material_ui/material_ui.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'project_detail_screen.dart';
import '../widgets/project_chat_sheet.dart';
import '../services/auth_service.dart'; // <-- WICHTIG: Importiert!
import 'login_screen.dart'; // <-- WICHTIG für den Logout-Button
import 'user_dashboard_screen.dart';
import 'profile_screen.dart';

class ProjectGridScreen extends StatefulWidget {
  const ProjectGridScreen({super.key});

  @override
  State<ProjectGridScreen> createState() => _ProjectGridScreenState();
}

class _ProjectGridScreenState extends State<ProjectGridScreen> {
  List<dynamic> _projects = [];
  bool _isLoading = true;

  final String baseUrl = 'http://127.0.0.1:8000/api';

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  // Projekte von der API laden
  Future<void> _fetchProjects() async {
    final headers = await AuthService.getHeaders(); // Token holen

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/projects'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        setState(() {
          _projects = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        // Wenn der Token ungültig ist (401), zurück zum Login
        if (response.statusCode == 401) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        } else {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Projekt löschen
  Future<void> _deleteProject(int id) async {
    final headers = await AuthService.getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/projects/$id'),
      headers: headers,
    );

    if (response.statusCode == 200 || response.statusCode == 204) {
      _fetchProjects();
    }
  }

  // Dialog zum Bearbeiten oder Erstellen
  void _showProjectDialog({Map<String, dynamic>? project}) {
    final isEditing = project != null;
    final nameController = TextEditingController(text: project?['name'] ?? '');
    final descController = TextEditingController(
      text: project?['description'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Projekt bearbeiten' : 'Neues Projekt'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Projektname'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Beschreibung'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final desc = descController.text.trim();
              if (name.isEmpty) return;

              Navigator.pop(context);

              final headers = await AuthService.getHeaders(); // Token holen

              if (isEditing) {
                await http.put(
                  Uri.parse('$baseUrl/projects/${project['id']}'),
                  headers: headers, // <-- Hier richtig eingefügt
                  body: json.encode({'name': name, 'description': desc}),
                );
              } else {
                await http.post(
                  Uri.parse('$baseUrl/projects'),
                  headers: headers, // <-- Hier richtig eingefügt
                  body: json.encode({'name': name, 'description': desc}),
                );
              }
              _fetchProjects();
            },
            child: Text(isEditing ? 'Speichern' : 'Erstellen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Projekte'),
        actions: [
          // Navigation zum Dashboard
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            tooltip: 'Dashboard',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserDashboardScreen()),
              );
            },
          ),
          // Navigation zum Profil
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
        ],
      ),
      // 👉 Der Plus-Button für neue Projekte
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showProjectDialog,
        icon: const Icon(Icons.add),
        label: const Text('Neues Projekt'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
          ? const Center(
              child: Text('Keine Projekte vorhanden. Erstelle dein erstes!'),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 250,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: _projects.length,
                itemBuilder: (context, index) {
                  final project = _projects[index];
                  return Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProjectDetailScreen(
                              projectId: project['id'],
                              projectName: project['name'] ?? 'Projekt',
                            ),
                          ),
                        ).then((_) {
                          _fetchProjects();
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    project['name'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showProjectDialog(project: project);
                                    } else if (value == 'delete') {
                                      _deleteProject(project['id']);
                                    } else if (value == 'comments') {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(20),
                                          ),
                                        ),
                                        builder: (_) => ChatSheet(
                                          targetId: project['id'],
                                          targetType: 'Project',
                                          targetName:
                                              project['name'] ?? 'Projekt',
                                        ),
                                      );
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => [
                                    const PopupMenuItem<String>(
                                      value: 'comments',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.forum,
                                            size: 18,
                                            color: Colors.green,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Kommentare'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.edit,
                                            size: 18,
                                            color: Colors.blue,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Bearbeiten'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete,
                                            size: 18,
                                            color: Colors.red,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Löschen'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Text(
                                project['description'] ?? 'Keine Beschreibung',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
