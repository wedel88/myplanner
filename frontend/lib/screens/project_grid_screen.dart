import 'package:material_ui/material_ui.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'project_detail_screen.dart';

class ProjectGridScreen extends StatefulWidget {
  const ProjectGridScreen({super.key});

  @override
  State<ProjectGridScreen> createState() => _ProjectGridScreenState();
}

class _ProjectGridScreenState extends State<ProjectGridScreen> {
  List<dynamic> _projects = [];
  bool _isLoading = true;

  // Passe hier deine API-URL an
  final String baseUrl = 'http://127.0.0.1:8000/api';

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  // Projekte von der API laden
  Future<void> _fetchProjects() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/projects'));
      if (response.statusCode == 200) {
        setState(() {
          _projects = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Projekt löschen
  Future<void> _deleteProject(int id) async {
    final response = await http.delete(Uri.parse('$baseUrl/projects/$id'));
    if (response.statusCode == 200) {
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

              if (isEditing) {
                await http.put(
                  Uri.parse('$baseUrl/projects/${project['id']}'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({'name': name, 'description': desc}),
                );
              } else {
                await http.post(
                  Uri.parse('$baseUrl/projects'),
                  headers: {'Content-Type': 'application/json'},
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
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showProjectDialog(),
            tooltip: 'Projekt hinzufügen',
          ),
        ],
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
                              projectId: project['id'], // Die ID des angeklickten Projekts
                              projectName: project['name'] ?? 'Projekt',
                            ),
                          ),
                        ).then((_) {
                          // Aktualisiert die Projektliste, wenn man vom Kanban-Board zurückkommt
                          _fetchProjects();
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project['name'] ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () =>
                                      _showProjectDialog(project: project),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                  onPressed: () =>
                                      _deleteProject(project['id']),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
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
