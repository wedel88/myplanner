import 'package:material_ui/material_ui.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:task_frontend/main.dart';

import '../services/auth_service.dart';
import '../widgets/app_navigation_bar.dart';
import 'project_detail_screen.dart';

class ArchivedProjectsScreen extends StatefulWidget {
  const ArchivedProjectsScreen({super.key});

  @override
  State<ArchivedProjectsScreen> createState() => _ArchivedProjectsScreenState();
}

class _ArchivedProjectsScreenState extends State<ArchivedProjectsScreen> {
  List<dynamic> _archivedProjects = [];
  bool _isLoading = true;
  final String baseUrl = '$apiBaseUrl';

  @override
  void initState() {
    super.initState();
    _fetchArchivedProjects();
  }

  Future<void> _fetchArchivedProjects() async {
    setState(() => _isLoading = true);
    try {
      final headers = await AuthService.getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/projects/archived/list'),
        headers: headers,
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _archivedProjects = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreProject(int id) async {
    // Optional: Methode zum Wiederherstellen (is_archived = false)
    final headers = await AuthService.getHeaders();
    try {
      await http.post(
        Uri.parse('$baseUrl/projects/$id/restore'),
        headers: headers,
      );
      _fetchArchivedProjects();
    } catch (e) {
      debugPrint('Fehler beim Wiederherstellen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppNavigationBar(
        currentRoute: '/archive',
        actions: [
          // Optionaler Button, um ein Projekt wiederherzustellen (falls du das möchtest)
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _archivedProjects.isEmpty
          ? const Center(child: Text('Keine archivierten Projekte gefunden.'))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ListView.builder(
                    itemCount: _archivedProjects.length,
                    itemBuilder: (context, index) {
                      final project = _archivedProjects[index];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.archive,
                              color: Colors.orange.shade700,
                            ),
                          ),
                          title: Text(
                            project['name'] ?? 'Unbenannt',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            'Projekt-ID: ${project['id']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.visibility,
                                  color: Colors.blue,
                                ),
                                tooltip: 'Ansehen',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProjectDetailScreen(
                                        projectId: project['id'],
                                        projectName:
                                            project['name'] ?? 'Projekt',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Optional: Restore Button
                              // IconButton(
                              //   icon: const Icon(Icons.restore, color: Colors.green),
                              //   tooltip: 'Wiederherstellen',
                              //   onPressed: () => _restoreProject(project['id']),
                              // ),
                            ],
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
