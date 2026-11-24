import 'package:material_ui/material_ui.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;

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

  final String baseUrl = 'http://127.0.0.1:8000/api';

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
    final headers = await AuthService.getHeaders();
    if (!mounted) return;

    final response = await http.post(
      Uri.parse('$baseUrl/projects/$id/archive'),
      headers: headers,
    );
    if (!mounted) return;

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Projekt archiviert!'),
          backgroundColor: Colors.green,
        ),
      );
      await _fetchProjects();
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

  // Dialog zum Bearbeiten oder Erstellen (mit optionaler Gruppen-Zuweisung)
  void _showProjectDialog({Map<String, dynamic>? project}) {
    final isEditing = project != null;
    final nameController = TextEditingController(text: project?['name'] ?? '');
    final descController = TextEditingController(
      text: project?['description'] ?? '',
    );
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
                        enabledBorder: OutlineInputBorder(
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
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                        enabledBorder: OutlineInputBorder(
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

                  final body = json.encode({
                    'name': name,
                    'description': desc,
                    if (selectedGroupId != null)
                      'group_id': int.parse(selectedGroupId!),
                    if (selectedGroupId == null) 'group_id': null,
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

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProjectDialog(),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Neues Projekt',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
                                      onSelected: (value) {
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

                                // NEU: Gruppe auf der rechten Seite als Badge
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
