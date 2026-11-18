import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;

import '../main.dart'; // Um an apiBaseUrl zu kommen
import 'project_detail_screen.dart';

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
        errorMessage = 'Verbindungsfehler: $e';
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
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (errorMessage.isNotEmpty) {
      return Center(
        child: Text(errorMessage, style: const TextStyle(color: Colors.red)),
      );
    }
    if (projects.isEmpty) {
      return const Center(child: Text('Noch keine Projekte vorhanden.'));
    }

    return RefreshIndicator(
      onRefresh: fetchProjects,
      child: ListView.builder(
        itemCount: projects.length,
        itemBuilder: (context, index) {
          final project = projects[index] as Map<String, dynamic>;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: Text(
                project['name']?.toString() ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(project['description']?.toString() ?? ''),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                final id = int.tryParse(project['id'].toString()) ?? 0;
                if (id > 0) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProjectDetailScreen(
                        projectId: id,
                        projectName: project['name']?.toString() ?? 'Projekt',
                      ),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}
