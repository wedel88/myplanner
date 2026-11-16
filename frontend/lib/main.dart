import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;

import 'dart:developer' as dev;

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
        errorMessage = 'Verbindungsfehler: $e\n(Läuft dein Laravel-Server?)';
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
                decoration: const InputDecoration(labelText: 'Projektname'),
                textCapitalization: TextCapitalization.sentences,
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Beschreibung'),
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
        body: jsonEncode({'name': name, 'description': description}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchProjects();
      } else {
        _showMessage('Fehler beim Speichern: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Verbindungsfehler: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
            style: const TextStyle(color: Colors.red, fontSize: 16),
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
          style: TextStyle(fontSize: 16, color: Colors.grey),
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
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(
                project['name']?.toString() ?? 'Unbenanntes Projekt',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                project['description']?.toString() ?? 'Keine Beschreibung',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                final id = project['id'];
                final parsedId = id == null
                    ? null
                    : int.tryParse(id.toString());

                if (parsedId == null) {
                  _showMessage('Das Projekt besitzt keine gültige ID.');
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProjectDetailScreen(
                      projectId: parsedId,
                      projectName: project['name']?.toString() ?? 'Projekt',
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
  bool _isReorderMode = false; // Steuer-Flag für den Spalten-Ordnungs-Modus
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
          errorMessage = 'Fehler beim Laden des Boards: ${response.statusCode}';
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

  void _showEditTaskDialog(
    int taskId,
    String currentTitle,
    String currentDesc,
  ) {
    final titleController = TextEditingController(text: currentTitle);
    final descriptionController = TextEditingController(text: currentDesc);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Aufgabe bearbeiten'),
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
                decoration: const InputDecoration(labelText: 'Beschreibung'),
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
                final newTitle = titleController.text.trim();
                final newDesc = descriptionController.text.trim();

                if (newTitle.isEmpty) return;

                Navigator.pop(dialogContext);
                await _updateTask(taskId, newTitle, newDesc);
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    ).then((_) {
      titleController.dispose();
      descriptionController.dispose();
    });
  }

  Future<void> _updateContainerPosition(
    int containerId,
    int newPosition,
  ) async {
    final url = Uri.parse('$apiBaseUrl/containers/$containerId/position');

    // Strukturierter Log-Aufruf
    dev.log(
      'Sende Position: Container $containerId -> Position $newPosition',
      name: 'ContainerAPI',
    );

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'position': newPosition}),
      );

      dev.log(
        'Antwort: ${response.statusCode} - ${response.body}',
        name: 'ContainerAPI',
      );
    } catch (e, stackTrace) {
      dev.log(
        'Fehler beim Position speichern',
        name: 'ContainerAPI',
        error: e,
        stackTrace: stackTrace,
      );
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
        body: jsonEncode({'project_id': widget.projectId, 'name': name}),
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

  // Spalte bearbeiten Dialog
  void _showEditContainerDialog(int containerId, String currentName) {
    final nameController = TextEditingController(text: currentName);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Spalte bearbeiten'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Spaltenname'),
            textCapitalization: TextCapitalization.sentences,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) return;

                Navigator.pop(dialogContext);
                await _updateContainer(containerId, newName);
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    ).then((_) => nameController.dispose());
  }

  Future<void> _updateContainer(int containerId, String name) async {
    final url = Uri.parse('$apiBaseUrl/containers/$containerId');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchBoardData();
        _showMessage('Spalte aktualisiert');
      } else {
        _showMessage('Fehler beim Aktualisieren: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Verbindungsfehler: $e');
    }
  }

  void _confirmDeleteContainer(int containerId, String containerName) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Spalte löschen?'),
          content: Text(
            'Möchtest du "$containerName" und alle darin enthaltenen Aufgaben wirklich löschen?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _deleteContainer(containerId);
              },
              child: const Text(
                'Löschen',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteContainer(int containerId) async {
    final url = Uri.parse('$apiBaseUrl/containers/$containerId');

    try {
      final response = await http.delete(url);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchBoardData();
        _showMessage('Spalte gelöscht');
      } else {
        _showMessage('Fehler beim Löschen: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Verbindungsfehler: $e');
    }
  }

  void _confirmDeleteTask(int taskId, String taskTitle) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Aufgabe löschen?'),
          content: Text(
            'Möchtest du "$taskTitle" wirklich unwiderruflich löschen?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _deleteTask(taskId);
              },
              child: const Text(
                'Löschen',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTask(int taskId) async {
    final url = Uri.parse('$apiBaseUrl/tasks/$taskId');

    try {
      final response = await http.delete(url);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchBoardData();
        _showMessage('Aufgabe gelöscht');
      } else {
        _showMessage('Fehler beim Löschen: ${response.statusCode}');
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
                decoration: const InputDecoration(labelText: 'Beschreibung'),
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
                await _createTask(containerId, title, description);
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

  Future<void> _moveTaskToContainer(int taskId, int newContainerId) async {
    final url = Uri.parse('$apiBaseUrl/tasks/$taskId');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'container_id': newContainerId}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        await fetchBoardData();
      } else {
        _showMessage('Fehler beim Verschieben: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Verbindungsfehler beim Verschieben: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectName),
        actions: [
          // Button zum Umschalten des Ordnungs-Modus
          IconButton(
            tooltip: _isReorderMode
                ? 'Ordnungs-Modus beenden'
                : 'Spalten ordnen',
            icon: Icon(
              _isReorderMode ? Icons.done : Icons.swap_horiz,
              color: _isReorderMode ? Colors.green : null,
            ),
            onPressed: () {
              setState(() {
                _isReorderMode = !_isReorderMode;
              });
            },
          ),
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

  Future<void> _updateTask(int taskId, String title, String description) async {
    final url = Uri.parse('$apiBaseUrl/tasks/$taskId');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'title': title, 'description': description}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchBoardData();
        _showMessage('Aufgabe aktualisiert');
      } else {
        _showMessage('Fehler beim Aktualisieren: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Verbindungsfehler: $e');
    }
  }

  // Einzige, saubere _buildBoardBody Methode
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

    if (_isReorderMode) {
      return ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8),
        itemCount: containers.length + 1,
        onReorder: (int oldIndex, int newIndex) async {
          if (oldIndex < newIndex) newIndex -= 1;
          if (oldIndex >= containers.length || newIndex >= containers.length) {
            return;
          }

          setState(() {
            final item = containers.removeAt(oldIndex);
            containers.insert(newIndex, item);
          });

          final container = containers[newIndex] as Map<String, dynamic>;
          final containerId = int.tryParse(container['id']?.toString() ?? '');
          if (containerId != null) {
            await _updateContainerPosition(containerId, newIndex);
          }
        },
        itemBuilder: (context, index) {
          return _buildContainerItem(index, isReorderable: true);
        },
      );
    } else {
      return ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8),
        itemCount: containers.length + 1,
        itemBuilder: (context, index) {
          return _buildContainerItem(index, isReorderable: false);
        },
      );
    }
  }

  // Hilfsmethode zur Erstellung einer Spalte (wiederverwendbar für Normal- & Reorder-Modus)
  Widget _buildContainerItem(int index, {required bool isReorderable}) {
    if (index == containers.length) {
      return SizedBox(
        key: const ValueKey('add_container_button'),
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
    final containerId = int.tryParse(container['id']?.toString() ?? '') ?? 0;
    final containerName = container['name']?.toString() ?? 'Spalte';

    return DragTarget<Map<String, dynamic>>(
      key: ValueKey('container_$containerId'),
      onAccept: (receivedTask) {
        final rawId = receivedTask['id'];
        final taskId = rawId != null ? int.tryParse(rawId.toString()) : null;
        if (taskId != null && containerId > 0) {
          _moveTaskToContainer(taskId, containerId);
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 300,
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty
                ? Colors.blue.shade100
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Spalten-Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Wenn der Ordnungs-Modus an ist, zeigen wir den Zieh-Griff
                  if (isReorderable)
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.only(right: 6.0),
                        child: Icon(Icons.drag_indicator, color: Colors.grey),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        containerName,
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
                    onPressed: () => _showCreateTaskDialog(containerId),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditContainerDialog(containerId, containerName);
                      } else if (value == 'delete') {
                        _confirmDeleteContainer(containerId, containerName);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Bearbeiten'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Löschen'),
                          ],
                        ),
                      ),
                    ],
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
                          final task = tasks[taskIndex] as Map<String, dynamic>;
                          final taskId =
                              int.tryParse(task['id']?.toString() ?? '') ?? 0;
                          final taskTitle =
                              task['title']?.toString() ?? 'Aufgabe';
                          final taskDesc =
                              task['description']?.toString() ?? '';

                          return Draggable<Map<String, dynamic>>(
                            data: task,
                            dragAnchorStrategy: pointerDragAnchorStrategy,
                            feedback: Material(
                              elevation: 4.0,
                              child: Container(
                                width: 250,
                                padding: const EdgeInsets.all(12),
                                color: Colors.blue,
                                child: Text(
                                  taskTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.5,
                              child: Card(
                                child: ListTile(
                                  title: Text(taskTitle),
                                  subtitle: Text(taskDesc),
                                ),
                              ),
                            ),
                            child: Card(
                              child: ListTile(
                                title: Text(taskTitle),
                                subtitle: Text(taskDesc),
                                // NEU: Das Drei-Punkte-Menü statt des direkten Mülleimer-Icons
                                trailing: PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      // Hier rufen wir gleich den Bearbeiten-Dialog für die Aufgabe auf
                                      _showEditTaskDialog(
                                        taskId,
                                        taskTitle,
                                        taskDesc,
                                      );
                                    } else if (value == 'delete') {
                                      _confirmDeleteTask(taskId, taskTitle);
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => [
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
