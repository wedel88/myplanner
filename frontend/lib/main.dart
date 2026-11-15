import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String apiBaseUrl = 'http://127.0.0.1:8000/api';

void main() {
  runApp(const MyPlannerApp());
}

class MyPlannerApp extends StatelessWidget {
  const MyPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyPlanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ProjectListScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// Projektübersicht
// -----------------------------------------------------------------------------

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen> {
  List<dynamic> projects = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchProjects();
  }

  Future<void> fetchProjects() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    final url = Uri.parse('$apiBaseUrl/projects');

    try {
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);

        setState(() {
          projects = decodedData is List ? decodedData : [];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Fehler beim Laden: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage =
            'Verbindungsfehler: $e\n(Läuft dein Laravel-Server?)';
        isLoading = false;
      });
    }
  }

  void _showCreateProjectDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Neues Projekt erstellen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Projektname',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final description = descriptionController.text.trim();

                if (name.isEmpty) return;

                Navigator.pop(dialogContext);
                await _createProject(name, description);
              },
              child: const Text('Erstellen'),
            ),
          ],
        );
      },
    ).then((_) {
      nameController.dispose();
      descriptionController.dispose();
    });
  }

  Future<void> _createProject(String name, String description) async {
    final url = Uri.parse('$apiBaseUrl/projects');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'description': description,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchProjects();
      } else {
        _showMessage(
          'Fehler beim Speichern: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Verbindungsfehler: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MyPlanner – Projekte'),
        actions: [
          IconButton(
            tooltip: 'Aktualisieren',
            icon: const Icon(Icons.refresh),
            onPressed: fetchProjects,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateProjectDialog,
        tooltip: 'Neues Projekt',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    if (projects.isEmpty) {
      return const Center(
        child: Text(
          'Noch keine Projekte vorhanden.\n'
          'Erstelle eins über den Button unten!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchProjects,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: projects.length,
        itemBuilder: (context, index) {
          final project = projects[index] as Map<String, dynamic>;

          return Card(
            margin: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            child: ListTile(
              title: Text(
                project['name']?.toString() ?? 'Unbenanntes Projekt',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                project['description']?.toString() ??
                    'Keine Beschreibung',
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
              ),
              onTap: () {
                final id = project['id'];

                if (id == null) {
                  _showMessage('Das Projekt besitzt keine gültige ID.');
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProjectDetailScreen(
                      projectId: int.parse(id.toString()),
                      projectName:
                          project['name']?.toString() ?? 'Projekt',
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Projektdetails und Kanban-Board
// -----------------------------------------------------------------------------

class ProjectDetailScreen extends StatefulWidget {
  final int projectId;
  final String projectName;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  List<dynamic> containers = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchBoardData();
  }

  Future<void> fetchBoardData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    final url = Uri.parse(
      '$apiBaseUrl/projects/${widget.projectId}/containers',
    );

    try {
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(response.body);

        setState(() {
          containers = decodedData is List ? decodedData : [];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              'Fehler beim Laden des Boards: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Verbindungsfehler: $e';
        isLoading = false;
      });
    }
  }

  void _showCreateContainerDialog() {
    final nameController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Neue Spalte erstellen'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Spaltenname (z. B. In Progress)',
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();

                if (name.isEmpty) return;

                Navigator.pop(dialogContext);
                await _createContainer(name);
              },
              child: const Text('Erstellen'),
            ),
          ],
        );
      },
    ).then((_) => nameController.dispose());
  }

  Future<void> _createContainer(String name) async {
    final url = Uri.parse('$apiBaseUrl/containers');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'project_id': widget.projectId,
          'name': name,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchBoardData();
      } else {
        _showMessage(
          'Fehler beim Erstellen der Spalte: ${response.statusCode}\n'
          '${response.body}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Verbindungsfehler: $e');
    }
  }

  void _showCreateTaskDialog(int containerId) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Neue Aufgabe erstellen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Titel'),
                textCapitalization: TextCapitalization.sentences,
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Beschreibung',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final description = descriptionController.text.trim();

                if (title.isEmpty) return;

                Navigator.pop(dialogContext);
                await _createTask(
                  containerId,
                  title,
                  description,
                );
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        );
      },
    ).then((_) {
      titleController.dispose();
      descriptionController.dispose();
    });
  }

  Future<void> _createTask(
    int containerId,
    String title,
    String description,
  ) async {
    final url = Uri.parse('$apiBaseUrl/tasks');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'container_id': containerId,
          'title': title,
          'description': description,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchBoardData();
      } else {
        _showMessage(
          'Fehler beim Erstellen der Aufgabe: ${response.statusCode}\n'
          '${response.body}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Verbindungsfehler: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName),
        actions: [
          IconButton(
            tooltip: 'Aktualisieren',
            icon: const Icon(Icons.refresh),
            onPressed: fetchBoardData,
          ),
        ],
      ),
      body: _buildBoardBody(),
    );
  }

  Widget _buildBoardBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(8),
      itemCount: containers.length + 1,
      itemBuilder: (context, index) {
        // Das letzte Element ist der Button zum Hinzufügen einer Spalte.
        if (index == containers.length) {
          return SizedBox(
            width: 220,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _showCreateContainerDialog,
                icon: const Icon(Icons.add),
                label: const Text('Spalte hinzufügen'),
              ),
            ),
          );
        }

        final container = containers[index] as Map<String, dynamic>;
        final tasks = (container['tasks'] as List<dynamic>?) ?? [];
        final containerId = int.parse(container['id'].toString());

        return Container(
          width: 300,
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        container['name']?.toString() ?? 'Spalte',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Aufgabe hinzufügen',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () =>
                        _showCreateTaskDialog(containerId),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: tasks.isEmpty
                    ? const Center(
                        child: Text(
                          'Noch keine Aufgaben',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: tasks.length,
                        itemBuilder: (context, taskIndex) {
                          final task =
                              tasks[taskIndex] as Map<String, dynamic>;

                          return Card(
                            child: ListTile(
                              title: Text(
                                task['title']?.toString() ?? 'Aufgabe',
                              ),
                              subtitle: Text(
                                task['description']?.toString() ?? '',
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
