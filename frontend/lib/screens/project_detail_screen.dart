import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../widgets/kanban_container.dart';

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
  bool _isReorderMode = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchBoardData(showLoader: true);
  }

  Future<void> fetchBoardData({bool showLoader = false}) async {
    // Nur beim echten Initial-Laden den Loader anzeigen, sonst im Hintergrund laufen lassen
    if (showLoader) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    }

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

  Future<void> _updateContainerPosition(
    int containerId,
    int newPosition,
  ) async {
    final url = Uri.parse('$apiBaseUrl/containers/$containerId/position');

    try {
      await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'position': newPosition}),
      );
    } catch (e) {
      _showMessage('Fehler beim Verschieben der Spalte: $e');
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
          'Fehler beim Erstellen der Spalte: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Verbindungsfehler: $e');
    }
  }

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
          'Fehler beim Erstellen der Aufgabe: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Verbindungsfehler: $e');
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
      _showMessage('Verbindungsfehler: $e');
    }
  }

  void _showAddSubtaskDialog(int taskId) {
    final titleController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Neuen Teilpunkt hinzufügen'),
          content: TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Titel des Teilpunkts',
            ),
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                Navigator.pop(dialogContext);
                await _createSubtask(taskId, title);
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        );
      },
    ).then((_) => titleController.dispose());
  }

  Future<void> _createSubtask(int taskId, String title) async {
    final url = Uri.parse('$apiBaseUrl/subtasks');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'task_id': taskId,
          'title': title,
          'is_completed': false,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchBoardData();
      } else {
        _showMessage(
          'Fehler beim Erstellen des Teilpunkts: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Verbindungsfehler: $e');
    }
  }

  Future<void> _toggleSubtask(int subtaskId, bool currentStatus) async {
    final url = Uri.parse('$apiBaseUrl/subtasks/$subtaskId');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'is_completed': !currentStatus}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchBoardData();
      } else {
        _showMessage('Fehler beim Aktualisieren: ${response.statusCode}');
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
        title: Text(widget.projectName),
        actions: [
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
        onReorderItem: (int oldIndex, int newIndex) async {
          if (oldIndex >= containers.length || newIndex >= containers.length) {
            return;
          }

          setState(() {
            final item = containers.removeAt(oldIndex);
            containers.insert(newIndex, item);
          });

          for (int i = 0; i < containers.length; i++) {
            final container = containers[i] as Map<String, dynamic>;
            final containerId = int.tryParse(container['id']?.toString() ?? '');
            if (containerId != null) {
              await _updateContainerPosition(containerId, i);
            }
          }

          await fetchBoardData();
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
    final containerId = container['id'];

    return KanbanContainerWidget(
      key: ValueKey('container_$containerId'), // <--- HIER DEN KEY HINZUFÜGEN
      container: container,
      index: index,
      isReorderable: isReorderable,
      onTaskDropped: (task, containerId) {
        final rawId = task['id'];
        final taskId = rawId != null ? int.tryParse(rawId.toString()) : null;
        if (taskId != null && containerId > 0) {
          _moveTaskToContainer(taskId, containerId);
        }
      },
      onCreateTask: (containerId) => _showCreateTaskDialog(containerId),
      onEditContainer: (containerId, name) =>
          _showEditContainerDialog(containerId, name),
      onDeleteContainer: (containerId, name) =>
          _confirmDeleteContainer(containerId, name),
      onEditTask: (taskId, title, desc) =>
          _showEditTaskDialog(taskId, title, desc),
      onDeleteTask: (taskId, title) => _confirmDeleteTask(taskId, title),
      onAddSubtask: (taskId) => _showAddSubtaskDialog(taskId),
      onToggleSubtask: (subtaskId, currentStatus) =>
          _toggleSubtask(subtaskId, currentStatus),
    );
  }
}
