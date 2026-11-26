import 'package:material_ui/material_ui.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:task_frontend/main.dart';

import 'project_detail_screen.dart';
import '../widgets/project_chat_sheet.dart';
import '../widgets/app_navigation_bar.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class ProjectGridScreen extends StatefulWidget {
  const ProjectGridScreen({super.key});

  @override
  State<ProjectGridScreen> createState() => _ProjectGridScreenState();
}

class _ProjectGridScreenState extends State<ProjectGridScreen> {
  List<dynamic> _projects = [];
  List<dynamic> _groups =
      []; // Wird für den "Gruppe zuweisen" Dialog im Projekt benötigt
  bool _isLoading = true;
  bool _showArchived = false; // Steuert, ob archivierte Projekte geladen werden

  final String baseUrl = '$apiBaseUrl';

  @override
  void initState() {
    super.initState();
    _fetchProjects();
    _fetchGroups();
  }

  Future<void> _fetchProjects() async {
    final headers = await AuthService.getHeaders();
    if (!mounted) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/projects'),
        headers: headers,
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _projects = json.decode(response.body);
          _isLoading = false;
        });
      } else {
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
      if (mounted) setState(() => _isLoading = false);
    }
    final url = _showArchived
        ? '$baseUrl/projects?archived=1'
        : '$baseUrl/projects';
  }

  //archivieren
  Future<void> _archiveProject(int id) async {
    // Optional: Sicherheitsabfrage
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Projekt archivieren?'),
        content: const Text(
          'Das Projekt wird aus der Hauptansicht entfernt und ins Archiv verschoben.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Archivieren',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final headers = await AuthService.getHeaders();
      // Wir rufen die POST-Route auf, die wir in api.php definiert haben
      final response = await http.post(
        Uri.parse('$baseUrl/projects/$id/archive'),
        headers: headers,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Projekt erfolgreich archiviert!'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchProjects(); // Das Grid neu laden (archivierte Projekte verschwinden)
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Archivieren: ${response.statusCode}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Fehler beim Archivieren: $e');
    }
  }

  Future<void> _fetchGroups() async {
    final headers = await AuthService.getHeaders();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/groups'),
        headers: headers,
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _groups = jsonDecode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Gruppen: $e');
    }
  }

  Future<void> _deleteProject(int id) async {
    final headers = await AuthService.getHeaders();
    if (!mounted) return;

    final response = await http.delete(
      Uri.parse('$baseUrl/projects/$id'),
      headers: headers,
    );
    if (!mounted) return;

    if (response.statusCode == 200 || response.statusCode == 204) {
      await _fetchProjects();
    }
  }

  void _showTemplateDialog() async {
    final headers = await AuthService.getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/templates'),
      headers: headers,
    );

    if (response.statusCode != 200) return;
    final templates = jsonDecode(response.body) as List;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Neues Projekt aus Vorlage'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: templates.isEmpty
              ? const Center(
                  child: Text(
                    'Keine Vorlagen vorhanden.\nSpeichere ein Projekt als Vorlage.',
                  ),
                )
              : ListView.builder(
                  itemCount: templates.length,
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.copy_all, color: Colors.blue),
                        title: Text(template['name'] ?? 'Vorlage'),
                        subtitle: Text(
                          '${template['containers']?.length ?? 0} Spalten',
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          // Nach neuem Namen fragen
                          final nameController = TextEditingController(
                            text: '${template['name']} Kopie',
                          );
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Projektname'),
                              content: TextField(
                                controller: nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Name',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Abbrechen'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Erstellen'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            final body = jsonEncode({
                              'template_id': template['id'],
                              'name': nameController.text.trim(),
                            });
                            await http.post(
                              Uri.parse('$baseUrl/projects/from-template'),
                              headers: headers,
                              body: body,
                            );
                            _fetchProjects();
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  // Dialog zum Bearbeiten oder Erstellen (mit optionaler Gruppen-Zuweisung)
  void _showProjectDialog({Map<String, dynamic>? project}) {
    final isEditing = project != null;
    final nameController = TextEditingController(text: project?['name'] ?? '');
    final descController = TextEditingController(
      text: project?['description'] ?? '',
    );

    // NEU: Zustand für die Checkbox "Als Vorlage speichern"
    bool isTemplate = project?['is_template'] == true;

    // NEU: Zustand für das Projekt-Deadline-Datum
    DateTime? selectedDueAt;
    if (project != null && project['due_at'] != null) {
      selectedDueAt = DateTime.tryParse(project['due_at']);
    }

    String? selectedGroupId = project?['group_id']?.toString();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(isEditing ? 'Projekt bearbeiten' : 'Neues Projekt'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Projektname',
                        filled: true,
                        fillColor: Colors.grey.withOpacity(0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Beschreibung',
                        filled: true,
                        fillColor: Colors.grey.withOpacity(0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Deadline Picker
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDueAt ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setStateDialog(() => selectedDueAt = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Projekt-Deadline (optional)',
                          suffixIcon: const Icon(Icons.calendar_today),
                          filled: true,
                          fillColor: Colors.grey.withOpacity(0.04),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Text(
                          selectedDueAt != null
                              ? "${selectedDueAt!.day.toString().padLeft(2, '0')}.${selectedDueAt!.month.toString().padLeft(2, '0')}.${selectedDueAt!.year}"
                              : 'Keine Deadline',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Gruppen-Dropdown
                    DropdownButtonFormField<String?>(
                      value: selectedGroupId,
                      decoration: InputDecoration(
                        labelText: 'Gruppe (optional)',
                        filled: true,
                        fillColor: Colors.grey.withOpacity(0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Keine Gruppe'),
                        ),
                        ..._groups.map(
                          (g) => DropdownMenuItem<String?>(
                            value: g['id'].toString(),
                            child: Text(g['name'] ?? ''),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setStateDialog(() => selectedGroupId = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Checkbox für Vorlage
                    SwitchListTile(
                      title: const Text(
                        'Als Vorlage speichern',
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Das Projekt wird als Vorlage für neue Projekte gespeichert.',
                        style: TextStyle(fontSize: 11),
                      ),
                      value: isTemplate,
                      activeColor: Colors.purple,
                      onChanged: (val) {
                        setStateDialog(() => isTemplate = val);
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onPressed: () async {
                  final name = nameController.text.trim();
                  final desc = descController.text.trim();
                  if (name.isEmpty) return;

                  Navigator.pop(context);
                  final headers = await AuthService.getHeaders();
                  if (!mounted) return;

                  // =========================================================
                  // HIER GEHÖRT DEIN BODY HIN
                  // =========================================================
                  final body = json.encode({
                    'name': name,
                    'description': desc,
                    if (selectedGroupId != null)
                      'group_id': int.parse(selectedGroupId!),
                    if (selectedGroupId == null) 'group_id': null,
                    'is_template': isTemplate, // <-- NEU
                    'due_at': selectedDueAt?.toIso8601String(), // <-- NEU
                  });

                  try {
                    if (isEditing) {
                      await http.put(
                        Uri.parse('$baseUrl/projects/${project['id']}'),
                        headers: headers,
                        body: body,
                      );
                    } else {
                      await http.post(
                        Uri.parse('$baseUrl/projects'),
                        headers: headers,
                        body: body,
                      );
                    }
                    if (!mounted) return;
                    await _fetchProjects();
                  } catch (e) {
                    debugPrint('Fehler beim Speichern des Projekts: $e');
                  }
                },
                child: Text(isEditing ? 'Speichern' : 'Erstellen'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50, // Konsistenter Hintergrund
      appBar: const AppNavigationBar(currentRoute: '/home'),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 1. Der Vorlagen-Button (kleiner, weiter oben)
          FloatingActionButton.extended(
            heroTag: 'template_fab', // Wichtig, damit sich die zwei FABs nicht in die Quere kommen
            onPressed: _showTemplateDialog,
            backgroundColor: Colors.purple.shade50,
            foregroundColor: Colors.purple.shade700,
            icon: const Icon(Icons.copy_all, size: 20),
            label: const Text(
              'Aus Vorlage',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12), // Abstand zwischen den Buttons
          // 2. Der normale "Neues Projekt"-Button
          FloatingActionButton.extended(
            heroTag: 'new_project_fab',
            onPressed: () => _showProjectDialog(),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text(
              'Neues Projekt',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
          ? const Center(
              child: Text('Keine Projekte vorhanden. Erstelle dein erstes!'),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 320,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          childAspectRatio: 1.1, // Etwas breiter für mehr Text
                        ),
                    itemCount: _projects.length,
                    itemBuilder: (context, index) {
                      final project = _projects[index];

                      return Card(
                        elevation: 0, // Kein Schatten, für den modernen Look
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProjectDetailScreen(
                                  projectId: project['id'],
                                  projectName: project['name'] ?? 'Projekt',
                                ),
                              ),
                            ).then((_) => _fetchProjects());
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Kopfzeile: Titel und Menü
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        project['name'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      icon: Icon(
                                        Icons.more_vert,
                                        size: 20,
                                        color: Colors.grey.shade600,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      onSelected: (value) async {
                                        if (value == 'edit') {
                                          _showProjectDialog(project: project);
                                        } else if (value == 'delete') {
                                          _deleteProject(project['id']);
                                        } else if (value == 'archive') {
                                          _archiveProject(project['id']);
                                        } else if (value == 'comments') {
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            shape: const RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.vertical(
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
                                        } else if (value == 'mark_template') {
                                          final headers =
                                              await AuthService.getHeaders();
                                          await http.post(
                                            Uri.parse(
                                              '$baseUrl/projects/${project['id']}/mark-template',
                                            ),
                                            headers: headers,
                                          );
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Als Vorlage gespeichert!',
                                                  ),
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
                                          value: 'mark_template',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.bookmark_add,
                                                size: 18,
                                                color: Colors.purple,
                                              ),
                                              SizedBox(width: 8),
                                              Text('Als Vorlage speichern'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem<String>(
                                          value: 'archive',
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.archive,
                                                size: 18,
                                                color: Colors.orange,
                                              ),
                                              SizedBox(width: 8),
                                              Text('Archivieren'),
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

                                // Beschreibung
                                Expanded(
                                  child: Text(
                                    project['description'] ??
                                        'Keine Beschreibung',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                      height: 1.4,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                // ===============GRUPPEN BADGE!!!!
                                if (project['group'] != null) ...[
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.blue.shade100,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.group,
                                            size: 12,
                                            color: Colors.blue.shade700,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            project['group']['name'],
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.blue.shade800,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                // =====DEADLINE Zeiger!====
                                if (project['due_at'] != null) ...[
                                  Builder(
                                    builder: (context) {
                                      // 1. Datum berechnen
                                      final dueDate = DateTime.parse(
                                        project['due_at'],
                                      );
                                      final now = DateTime.now();
                                      final difference = dueDate
                                          .difference(now)
                                          .inDays;

                                      // 2. Farbe basierend auf der Differenz wählen
                                      Color bgColor;
                                      Color textColor;
                                      Color borderColor;

                                      if (difference < 0) {
                                        // Überfällig (Rot)
                                        bgColor = Colors.red.shade50;
                                        textColor = Colors.red.shade700;
                                        borderColor = Colors.red.shade200;
                                      } else if (difference <= 14) {
                                        // Weniger als 2 Wochen (Orange)
                                        bgColor = Colors.orange.shade50;
                                        textColor = Colors.orange.shade800;
                                        borderColor = Colors.orange.shade200;
                                      } else {
                                        // Mehr als 2 Wochen (Grau)
                                        bgColor = Colors.grey.shade100;
                                        textColor = Colors.grey.shade700;
                                        borderColor = Colors.grey.shade300;
                                      }

                                      return Align(
                                        alignment: Alignment.centerRight,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: bgColor,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: borderColor,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                size: 12,
                                                color: textColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Bis: ${project['due_at'].toString().substring(0, 10)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: textColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }
}
