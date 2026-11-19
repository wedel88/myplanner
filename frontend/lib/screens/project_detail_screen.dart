import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;

import '../main.dart';
import '../widgets/kanban_container.dart';
import '../widgets/project_chat_sheet.dart';
import 'task_detail_screen.dart';

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

  Future<void> _updateContainerPosition(
    int containerId,
    int newPosition,
  ) async {
    final url = Uri.parse('$apiBaseUrl/containers/$containerId/reorder');

    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'position': newPosition}),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        debugPrint(
          'API-Fehler beim Verschieben: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Netzwerk-Fehler beim Verschieben: $e');
    }
  }

  void _showEditTaskDialog(
    int taskId,
    String currentTitle,
    String currentDesc,
    String currentStatus,
    String? currentDueAt,
  ) {
    final titleController = TextEditingController(text: currentTitle);
    final descriptionController = TextEditingController(text: currentDesc);
    String selectedStatus = currentStatus;

    DateTime? selectedDate = currentDueAt != null
        ? DateTime.tryParse(currentDueAt)
        : null;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Aufgabe bearbeiten'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Titel'),
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Beschreibung',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(labelText: 'Status'),
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
                      onChanged: (value) {
                        if (value != null) {
                          setStateDialog(() => selectedStatus = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          setStateDialog(() {
                            selectedDate = pickedDate;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Ablaufdatum (optional)',
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          selectedDate != null
                              ? "${selectedDate!.day.toString().padLeft(2, '0')}.${selectedDate!.month.toString().padLeft(2, '0')}.${selectedDate!.year}"
                              : 'Kein Datum ausgewählt',
                        ),
                      ),
                    ),
                  ],
                ),
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
                    await _updateTask(
                      taskId,
                      newTitle,
                      newDesc,
                      selectedStatus,
                      selectedDate?.toIso8601String(),
                    );
                  },
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      titleController.dispose();
      descriptionController.dispose();
    });
  }

  Future<void> _updateTask(
    int taskId,
    String title,
    String description,
    String status,
    String? dueAt,
  ) async {
    final url = Uri.parse('$apiBaseUrl/tasks/$taskId');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'description': description,
          'status': status,
          'due_at': dueAt,
        }),
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

  Future<void> _updateSubtaskTitle(int subtaskId, String newTitle) async {
    final url = Uri.parse('$apiBaseUrl/subtasks/$subtaskId');

    try {
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'title': newTitle}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchBoardData();
        _showMessage('Teilpunkt aktualisiert');
      } else {
        _showMessage('Fehler beim Aktualisieren: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Verbindungsfehler: $e');
    }
  }

  Future<void> _updateTaskOrder(
    int taskId,
    int containerId,
    int newPosition,
  ) async {
    final url = Uri.parse('$apiBaseUrl/tasks/$taskId/reorder');

    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'container_id': containerId,
          'position': newPosition,
        }),
      );

      if (!mounted) return;

      if (response.statusCode != 200 && response.statusCode != 204) {
        debugPrint(
          'Fehler beim Speichern der Task-Position: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Netzwerkfehler beim Speichern der Task-Position: $e');
    }
  }

  Future<void> _deleteSubtask(int subtaskId) async {
    final url = Uri.parse('$apiBaseUrl/subtasks/$subtaskId');

    try {
      final response = await http.delete(url);

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchBoardData();
        _showMessage('Teilpunkt gelöscht');
      } else {
        _showMessage('Fehler beim Löschen: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Verbindungsfehler: $e');
    }
  }

  void _showManageSubtasksDialog(Map<String, dynamic> task) {
    List<dynamic> subtasks = List.from(task['subtasks'] ?? []);
    final taskTitle = task['title']?.toString() ?? 'Aufgabe';

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Teilpunkte verwalten\n("$taskTitle")'),
              content: SizedBox(
                width: 300,
                height: subtasks.isEmpty
                    ? 50.0
                    : (subtasks.length * 60).clamp(50, 300).toDouble(),
                child: subtasks.isEmpty
                    ? const Center(child: Text('Keine Teilpunkte vorhanden.'))
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: subtasks.length,
                        itemBuilder: (context, index) {
                          final subtask = subtasks[index];
                          final subId =
                              int.tryParse(subtask['id']?.toString() ?? '') ??
                              0;
                          final subTitle = subtask['title']?.toString() ?? '';

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              subTitle,
                              style: const TextStyle(fontSize: 14),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 18,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    _showEditSubtaskDialog(subId, subTitle, (
                                      updatedTitle,
                                    ) async {
                                      await _updateSubtaskTitle(
                                        subId,
                                        updatedTitle,
                                      );
                                      setStateDialog(() {
                                        subtask['title'] = updatedTitle;
                                      });
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    await _deleteSubtask(subId);
                                    setStateDialog(() {
                                      subtasks.removeWhere(
                                        (s) =>
                                            int.tryParse(
                                              s['id']?.toString() ?? '',
                                            ) ==
                                            subId,
                                      );
                                    });
                                    await fetchBoardData(showLoader: false);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Schließen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditSubtaskDialog(
    int subtaskId,
    String currentTitle,
    Function(String) onSaved,
  ) {
    final controller = TextEditingController(text: currentTitle);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Teilpunkt bearbeiten'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Titel'),
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
                final newTitle = controller.text.trim();
                if (newTitle.isEmpty) return;

                Navigator.pop(dialogContext);
                onSaved(newTitle);
                await fetchBoardData(showLoader: false);
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    ).then((_) => controller.dispose());
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
            onPressed: () async {
              if (_isReorderMode) {
                setState(() {
                  _isReorderMode = false;
                });
                final currentContainers = List.from(containers);

                for (int i = 0; i < currentContainers.length; i++) {
                  final container =
                      currentContainers[i] as Map<String, dynamic>;
                  final containerId = int.tryParse(
                    container['id']?.toString() ?? '',
                  );

                  if (containerId != null) {
                    try {
                      await _updateContainerPosition(containerId, i);
                    } catch (e) {
                      debugPrint(
                        'Fehler beim Speichern von Container $containerId: $e',
                      );
                    }
                  }
                }
                await fetchBoardData(showLoader: false);
              } else {
                setState(() {
                  _isReorderMode = true;
                });
              }
            },
          ),
          IconButton(
            tooltip: 'Projekt-Chat',
            icon: const Icon(Icons.forum),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => ChatSheet(
                  targetId: widget.projectId,
                  targetType: 'Project',
                  targetName: widget.projectName,
                ),
              );
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
        itemCount: containers.length,
        buildDefaultDragHandles: false,
        onReorderItem: (int oldIndex, int newIndex) async {
          if (oldIndex < newIndex) newIndex -= 1;

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
          return KeyedSubtree(
            key: ValueKey('container_reorder_$index'),
            child: _buildContainerItem(index, isReorderable: true),
          );
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
    final containerId = int.tryParse(container['id']?.toString() ?? '') ?? 0;

    final kanbanWidget = ReorderableDragStartListener(
      index: index,
      enabled: isReorderable,
      child: KanbanContainerWidget(
        key: ValueKey('container_$containerId'),
        container: container,
        index: index,
        isReorderable: isReorderable,
        isReorderMode: isReorderable,
        onTaskDropped: (task, cId, newPos) {
          if (!isReorderable) {
            final rawId = task['id'];
            final taskId = rawId != null
                ? int.tryParse(rawId.toString())
                : null;

            if (taskId != null && cId > 0) {
              setState(() {
                final sourceContainer = containers.firstWhere(
                  (c) => (c['tasks'] as List).any((t) => t['id'] == taskId),
                  orElse: () => {},
                );
                if (sourceContainer != null) {
                  (sourceContainer['tasks'] as List).removeWhere(
                    (t) => t['id'] == taskId,
                  );
                }

                final targetContainer = containers.firstWhere(
                  (c) => int.tryParse(c['id']?.toString() ?? '') == cId,
                  orElse: () => {},
                );
                if (targetContainer != null) {
                  final targetTasks = targetContainer['tasks'] as List;
                  final insertIndex = newPos > targetTasks.length
                      ? targetTasks.length
                      : newPos;
                  targetTasks.insert(insertIndex, task);
                }
              });

              _updateTaskOrder(taskId, cId, newPos);
            }
          }
        },
        onCreateTask: (cId) => _showCreateTaskDialog(cId),
        onEditContainer: (cId, name) => _showEditContainerDialog(cId, name),
        onDeleteContainer: (cId, name) => _confirmDeleteContainer(cId, name),
        onEditTask: (taskId, title, desc, status, dueAt) =>
            _showEditTaskDialog(taskId, title, desc, status, dueAt),
        onDeleteTask: (taskId, title) => _confirmDeleteTask(taskId, title),
        onAddSubtask: (taskId) => _showAddSubtaskDialog(taskId),
        onToggleSubtask: (subtaskId, currentStatus) =>
            _toggleSubtask(subtaskId, currentStatus),
        onManageSubtasks: (taskData) => _showManageSubtasksDialog(taskData),
        onTaskTap: (Map<String, dynamic> taskData) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskDetailScreen(
                task: taskData,
                onTaskUpdated: () => fetchBoardData(showLoader: false),
              ),
            ),
          );
        },
      ),
    );

    return kanbanWidget;
  }
}
