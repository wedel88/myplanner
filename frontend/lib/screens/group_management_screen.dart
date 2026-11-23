import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';

class GroupManagementScreen extends StatefulWidget {
  final String apiBaseUrl;

  const GroupManagementScreen({Key? key, required this.apiBaseUrl})
    : super(key: key);

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  List<dynamic> _myGroups = [];
  Map<String, dynamic>? _selectedGroup;
  List<dynamic> _members = [];
  List<dynamic> _projects = [];
  bool _isLoading = true;
  String? _error;

  // Speichert die Rolle des aktuellen Users in der aktiven Gruppe
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _fetchMyGroups();
  }

  // Hilfsfunktionen für Berechtigungen
  bool get _isAdmin => _currentUserRole == 'admin';
  bool get _canManageMembers =>
      _currentUserRole == 'admin' || _currentUserRole == 'product_owner';
  bool get _canManageProjects =>
      _currentUserRole == 'admin' || _currentUserRole == 'product_owner';

  // ==================== 1. DATEN LADEN ====================

  Future<void> _fetchMyGroups() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final headers = await AuthService.getHeaders();
      final response = await http.get(
        Uri.parse('${widget.apiBaseUrl}/groups'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> groups = jsonDecode(response.body);
        setState(() {
          _myGroups = groups;
          if (_myGroups.isNotEmpty) {
            _selectedGroup = _myGroups.first;
            _fetchGroupDetails(_selectedGroup!['id']);
          } else {
            _isLoading = false;
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Fehler ${response.statusCode} beim Laden der Gruppen';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Netzwerkfehler: $e';
      });
    }
  }

  Future<void> _fetchGroupDetails(int groupId) async {
    setState(() => _isLoading = true);
    try {
      final headers = await AuthService.getHeaders();
      final response = await http.get(
        Uri.parse('${widget.apiBaseUrl}/groups/$groupId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final int? me = await AuthService.getCurrentUserId();

        // Rolle des aktuellen Users ermitteln
        String? myRole;
        for (var user in (data['users'] ?? [])) {
          if (user['id'] == me) {
            myRole = user['pivot']?['role'];
            break;
          }
        }

        setState(() {
          _members = data['users'] ?? [];
          _projects = data['projects'] ?? [];
          _currentUserRole = myRole;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Gruppendetails: $e');
      setState(() => _isLoading = false);
    }
  }

  // ==================== 2. MITGLIEDER VERWALTEN ====================

  Future<void> _updateMemberRole(
    int userId,
    String userName,
    String newRole,
  ) async {
    final roleNames = {
      'admin': 'Admin',
      'product_owner': 'Product Owner',
      'member': 'Mitglied',
    };

    final confirmed = await _showConfirmationDialog(
      'Rolle ändern',
      'Möchtest du die Rolle von $userName wirklich zu "${roleNames[newRole]}" ändern?',
    );

    if (!confirmed) {
      _fetchGroupDetails(_selectedGroup!['id']); // UI zurücksetzen
      return;
    }

    try {
      final headers = await AuthService.getHeaders();
      final groupId = _selectedGroup!['id'];

      final response = await http.put(
        Uri.parse('${widget.apiBaseUrl}/groups/$groupId/members/$userId'),
        headers: headers,
        body: jsonEncode({'role': newRole}),
      );

      if (response.statusCode == 200) {
        _fetchGroupDetails(groupId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rolle erfolgreich aktualisiert!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Fehler beim Ändern der Rolle: $e');
    }
  }

  Future<void> _removeMember(int userId, String userName) async {
    final confirmed = await _showConfirmationDialog(
      'Mitglied entfernen',
      'Möchtest du $userName wirklich aus dieser Gruppe entfernen?',
    );

    if (!confirmed) return;

    try {
      final headers = await AuthService.getHeaders();
      final groupId = _selectedGroup!['id'];

      final response = await http.delete(
        Uri.parse('${widget.apiBaseUrl}/groups/$groupId/members/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        _fetchGroupDetails(groupId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mitglied wurde entfernt.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Fehler beim Entfernen: $e');
    }
  }

  // ==================== 3. PROJEKTE VERWALTEN ====================

  // NEU: Dialog zum Hinzufügen verfügbarer Projekte
  void _showAddProjectDialog() async {
    setState(() => _isLoading = true);
    List<dynamic> availableProjects = [];

    try {
      final headers = await AuthService.getHeaders();
      final response = await http.get(
        Uri.parse('${widget.apiBaseUrl}/groups/available-projects'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        availableProjects = jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Fehler beim Laden verfügbarer Projekte: $e');
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Projekt zur Gruppe hinzufügen'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: availableProjects.isEmpty
              ? const Center(
                  child: Text(
                    'Keine verfügbaren Projekte gefunden.\n(Alle deine Projekte sind bereits in Gruppen.)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: availableProjects.length,
                  itemBuilder: (context, index) {
                    final project = availableProjects[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.folder, color: Colors.blue),
                        title: Text(
                          project['name'] ?? 'Projekt',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          project['description'] ?? 'Keine Beschreibung',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(
                          Icons.add_circle,
                          color: Colors.green,
                        ),
                        onTap: () async {
                          Navigator.pop(context); // Dialog schließen
                          await _assignProjectToGroup(project['id']);
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

  Future<void> _assignProjectToGroup(int projectId) async {
    try {
      final headers = await AuthService.getHeaders();
      final response = await http.post(
        Uri.parse(
          '${widget.apiBaseUrl}/groups/${_selectedGroup!['id']}/projects/assign',
        ),
        headers: headers,
        body: jsonEncode({'project_id': projectId}),
      );
      if (response.statusCode == 200) {
        _fetchGroupDetails(_selectedGroup!['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Projekt erfolgreich hinzugefügt!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fehler beim Hinzufügen (Berechtigung?)'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Fehler beim Zuweisen: $e');
    }
  }

  Future<void> _removeProjectFromGroup(
    int projectId,
    String projectName,
  ) async {
    final confirmed = await _showConfirmationDialog(
      'Projekt entfernen',
      'Möchtest du "$projectName" wirklich aus dieser Gruppe entfernen?\n(Das Projekt selbst wird nicht gelöscht, nur die Zuordnung zur Gruppe aufgehoben).',
    );
    if (!confirmed) return;

    try {
      final headers = await AuthService.getHeaders();
      final response = await http.delete(
        Uri.parse(
          '${widget.apiBaseUrl}/groups/${_selectedGroup!['id']}/projects/$projectId',
        ),
        headers: headers,
      );
      if (response.statusCode == 200) {
        _fetchGroupDetails(_selectedGroup!['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Projekt aus Gruppe entfernt!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Fehler beim Entfernen: $e');
    }
  }

  // ==================== 4. GRUPPE ERSTELLEN & EINLADEN ====================

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Neue Gruppe erstellen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Gruppenname',
                filled: true,
                fillColor: Colors.grey.withOpacity(0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: 'Beschreibung (optional)',
                filled: true,
                fillColor: Colors.grey.withOpacity(0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
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
            ),
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(context);

              try {
                final headers = await AuthService.getHeaders();
                final response = await http.post(
                  Uri.parse('${widget.apiBaseUrl}/groups'),
                  headers: headers,
                  body: jsonEncode({
                    'name': nameController.text.trim(),
                    'description': descController.text.trim(),
                  }),
                );

                if (response.statusCode == 201) {
                  _fetchMyGroups();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Gruppe erfolgreich erstellt!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              } catch (e) {
                debugPrint('Fehler beim Erstellen: $e');
              }
            },
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );
  }

  void _openInviteDialog() async {
    if (_selectedGroup == null) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => InviteMemberDialog(
        groupId: _selectedGroup!['id'],
        apiBaseUrl: widget.apiBaseUrl,
      ),
    );

    if (result == true) {
      _fetchGroupDetails(_selectedGroup!['id']);
    }
  }

  // ==================== UTILS ====================

  Future<bool> _showConfirmationDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bestätigen'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'admin':
        return Colors.red.shade700;
      case 'product_owner':
        return Colors.orange.shade800;
      default:
        return Colors.blue.shade700;
    }
  }

  // ==================== UI BUILD ====================

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gruppenverwaltung')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                onPressed: _fetchMyGroups,
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gruppen- & Mitgliederverwaltung'),
        elevation: 0,
      ),
      body: _isLoading && _myGroups.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 900 : double.infinity,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ==================== GRUPPEN-AUSWAHL ====================
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: _selectedGroup?['id'],
                              decoration: InputDecoration(
                                labelText: 'Aktive Gruppe wählen',
                                filled: true,
                                fillColor: Colors.grey.withOpacity(0.04),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: _myGroups.map((group) {
                                return DropdownMenuItem<int>(
                                  value: group['id'],
                                  child: Text(
                                    group['name'] ?? 'Unbekannte Gruppe',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (newId) {
                                if (newId != null) {
                                  final newGroup = _myGroups.firstWhere(
                                    (g) => g['id'] == newId,
                                  );
                                  setState(() => _selectedGroup = newGroup);
                                  _fetchGroupDetails(newId);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _showCreateGroupDialog,
                            icon: const Icon(Icons.group_add, size: 18),
                            label: const Text('Neue Gruppe'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      if (_selectedGroup != null) ...[
                        // ==================== MITGLIEDER LISTE ====================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Mitglieder (${_members.length})',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (_canManageMembers)
                              ElevatedButton.icon(
                                onPressed: _openInviteDialog,
                                icon: const Icon(
                                  Icons.person_add_alt_1,
                                  size: 18,
                                ),
                                label: const Text('Mitglied einladen'),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _isLoading
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _members.length,
                                itemBuilder: (context, index) {
                                  final user = _members[index];
                                  final pivot = user['pivot'] ?? {};
                                  final currentRole = pivot['role'] ?? 'member';

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    elevation: 0,
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.blue.shade100,
                                        child: Text(
                                          (user['name'] ?? 'U')[0]
                                              .toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.blue.shade900,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        user['name'] ?? 'Unbekannt',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text(user['email'] ?? ''),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getRoleColor(currentRole)
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: currentRole,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getRoleColor(
                                                    currentRole,
                                                  ),
                                                ),
                                                items: const [
                                                  DropdownMenuItem(
                                                    value: 'member',
                                                    child: Text('Mitglied'),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: 'product_owner',
                                                    child: Text(
                                                      'Product Owner',
                                                    ),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: 'admin',
                                                    child: Text('Admin'),
                                                  ),
                                                ],
                                                onChanged: _isAdmin
                                                    ? (newRole) {
                                                        if (newRole != null &&
                                                            newRole !=
                                                                currentRole) {
                                                          _updateMemberRole(
                                                            user['id'],
                                                            user['name'] ??
                                                                'Nutzer',
                                                            newRole,
                                                          );
                                                        }
                                                      }
                                                    : null, // Deaktiviert für Nicht-Admins
                                              ),
                                            ),
                                          ),
                                          if (_isAdmin)
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                              ),
                                              onPressed: () => _removeMember(
                                                user['id'],
                                                user['name'] ?? 'Mitglied',
                                              ),
                                              tooltip: 'Entfernen',
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                        const Divider(height: 40),

                        // ==================== PROJEKTE LISTE ====================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Zugeordnete Projekte (${_projects.length})',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (_canManageProjects)
                              ElevatedButton.icon(
                                onPressed: _showAddProjectDialog,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Projekt hinzufügen'),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _projects.isEmpty
                            ? const Text(
                                'Bisher sind dieser Gruppe keine Projekte zugewiesen.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _projects.length,
                                itemBuilder: (context, index) {
                                  final project = _projects[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    elevation: 0,
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.folder,
                                        color: Colors.blue,
                                      ),
                                      title: Text(
                                        project['name'] ?? 'Projekt',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: Text(
                                        project['description'] ??
                                            'Keine Beschreibung',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: _canManageProjects
                                          ? IconButton(
                                              icon: const Icon(
                                                Icons.link_off,
                                                color: Colors.orange,
                                              ),
                                              tooltip: 'Aus Gruppe entfernen',
                                              onPressed: () =>
                                                  _removeProjectFromGroup(
                                                    project['id'],
                                                    project['name'] ??
                                                        'Projekt',
                                                  ),
                                            )
                                          : null,
                                    ),
                                  );
                                },
                              ),
                      ] else
                        const Center(
                          child: Text(
                            'Keine Gruppen vorhanden. Erstelle eine neue Gruppe!',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

// ==================== INVITE MEMBER DIALOG ====================
class InviteMemberDialog extends StatefulWidget {
  final int groupId;
  final String apiBaseUrl;

  const InviteMemberDialog({
    Key? key,
    required this.groupId,
    required this.apiBaseUrl,
  }) : super(key: key);

  @override
  State<InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<InviteMemberDialog> {
  final _emailController = TextEditingController();
  String _selectedRole = 'member';
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _inviteMember() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final headers = await AuthService.getHeaders();
      final response = await http.post(
        Uri.parse('${widget.apiBaseUrl}/groups/${widget.groupId}/members'),
        headers: headers,
        body: jsonEncode({'email': email, 'role': _selectedRole}),
      );

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$email erfolgreich hinzugefügt!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final decoded = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decoded['message'] ?? 'Fehler beim Hinzufügen'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Netzwerkfehler: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.person_add_alt_1, color: Colors.blue),
          SizedBox(width: 8),
          Text('Mitglied einladen', style: TextStyle(fontSize: 18)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'E-Mail-Adresse',
              hintText: 'nutzer@example.com',
              filled: true,
              fillColor: Colors.grey.withOpacity(0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedRole,
            decoration: InputDecoration(
              labelText: 'Rolle in der Gruppe',
              filled: true,
              fillColor: Colors.grey.withOpacity(0.04),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'member',
                child: Text('Mitglied (Standard)'),
              ),
              DropdownMenuItem(
                value: 'product_owner',
                child: Text('Product Owner (Projekte verwalten)'),
              ),
              DropdownMenuItem(
                value: 'admin',
                child: Text('Admin (Vollzugriff)'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedRole = value);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _inviteMember,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Einladen'),
        ),
      ],
    );
  }
}
