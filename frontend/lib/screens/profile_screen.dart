import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import 'project_grid_screen.dart';
import 'user_dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  Map<String, dynamic> _userData = {};
  String _errorMessage = '';

  // Controller für die bearbeitbaren Felder
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  // Controller für Passwort-Änderung
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController(); // NEU

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final headers = await AuthService.getHeaders();
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/api/me'),
        headers: headers,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _userData = data;
          _nameController.text = data['name'] ?? '';
          _emailController.text = data['email'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Fehler beim Laden des Profils (${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Verbindungsfehler: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmAndUpdateProfile() async {
    // 1. Lokale Validierung (verhindert unnötige Netzwerkanfragen)
    if (_newPasswordController.text.isNotEmpty ||
        _confirmPasswordController.text.isNotEmpty) {
      if (_newPasswordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Die neuen Passwörter stimmen nicht überein!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // HIER: Die 6-Zeichen-Regel (passend zum Backend)
      if (_newPasswordController.text.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Das neue Passwort muss mindestens 6 Zeichen lang sein! (Kürzere Passwörter werden aus Sicherheitsgründen abgelehnt.)',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // 2. Sicherheitsabfrage
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Änderungen speichern?'),
        content: const Text(
          'Möchtest du deine Profil-Änderungen wirklich übernehmen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Nein'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ja'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _updateProfileData();
    }
  }

  Future<void> _updateProfileData() async {
    setState(() => _isSaving = true);
    try {
      final headers = await AuthService.getHeaders();
      final response = await http.put(
        Uri.parse('http://127.0.0.1:8000/api/profile'),
        headers: headers,
        body: json.encode({
          'name': _nameController.text,
          'email': _emailController.text,
          if (_newPasswordController.text.isNotEmpty) ...{
            'current_password': _currentPasswordController.text,
            'password': _newPasswordController.text,
          },
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil erfolgreich aktualisiert!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _isEditing = false);
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _fetchUserData();
      } else {
        final errorData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fehler: ${errorData['message'] ?? 'Unbekannter Fehler'}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verbindungsfehler: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Future<void> _pickAndCropImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 90,
    );

    if (pickedFile == null) return;
    final bytes = await pickedFile.readAsBytes();
    await _uploadAvatarBytes(bytes);
  }

  Future<void> _uploadAvatarBytes(Uint8List bytes) async {
    setState(() => _isSaving = true);
    try {
      final headers = await AuthService.getHeaders();
      headers.remove('Content-Type');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:8000/api/profile/avatar'),
      );
      request.headers.addAll(headers);
      request.files.add(
        http.MultipartFile.fromBytes('avatar', bytes, filename: 'avatar.jpg'),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profilbild erfolgreich aktualisiert!'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchUserData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Upload: ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verbindungsfehler: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- DESIGN BAUSTEINE ---

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    IconData? prefixIcon,
    bool enabled = true,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 20, color: Colors.grey.shade600)
            : null,
        filled: true,
        fillColor: enabled
            ? Colors.grey.withOpacity(0.04)
            : Colors.grey.shade100,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.blue, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    final userAvatarUrl = _userData['avatar'] != null
        ? 'http://127.0.0.1:8000/api/${_userData['avatar']}'
        : null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Mein Profil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            tooltip: 'Projekte (Home)',
            icon: const Icon(Icons.grid_view_rounded, color: Colors.black87),
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const ProjectGridScreen()),
              (route) => false,
            ),
          ),
          IconButton(
            tooltip: 'Dashboard',
            icon: const Icon(
              Icons.dashboard_outlined,
              color: Colors.deepOrange,
            ),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const UserDashboardScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Aktualisieren',
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _fetchUserData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 800 : double.infinity,
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
              ? Center(
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ==================== 1. AVATAR & HEADER ====================
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                image: DecorationImage(
                                  fit: BoxFit.cover,
                                  image:
                                      userAvatarUrl != null &&
                                          userAvatarUrl.isNotEmpty
                                      ? NetworkImage(userAvatarUrl)
                                            as ImageProvider
                                      : const AssetImage(
                                          'assets/default_avatar.png',
                                        ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: _pickAndCropImage,
                                borderRadius: BorderRadius.circular(50),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ==================== 2. SYSTEM INFO CARD ====================
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Benutzer-ID (fest)',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '${_userData['id'] ?? '-'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Mitglied seit',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _userData['created_at'] != null
                                      ? _userData['created_at']
                                            .toString()
                                            .substring(0, 10)
                                      : '-',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ==================== 3. PERSÖNLICHE DATEN ====================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Persönliche Daten',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          TextButton.icon(
                            icon: Icon(
                              _isEditing ? Icons.close : Icons.edit,
                              size: 18,
                            ),
                            label: Text(
                              _isEditing ? 'Abbrechen' : 'Bearbeiten',
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: _isEditing
                                  ? Colors.red
                                  : Colors.blue,
                            ),
                            onPressed: () {
                              setState(() {
                                if (_isEditing) {
                                  _nameController.text =
                                      _userData['name'] ?? '';
                                  _emailController.text =
                                      _userData['email'] ?? '';
                                  _currentPasswordController.clear();
                                  _newPasswordController.clear();
                                  _confirmPasswordController.clear();
                                }
                                _isEditing = !_isEditing;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _buildStyledTextField(
                        controller: _nameController,
                        label: 'Name',
                        prefixIcon: Icons.person,
                        enabled: _isEditing,
                      ),
                      const SizedBox(height: 16),
                      _buildStyledTextField(
                        controller: _emailController,
                        label: 'E-Mail-Adresse',
                        prefixIcon: Icons.email,
                        enabled: _isEditing,
                      ),

                      // ==================== 4. PASSWORT ÄNDERN ====================
                      if (_isEditing) ...[
                        const SizedBox(height: 32),
                        const Text(
                          'Passwort ändern (optional)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 12),

                        _buildStyledTextField(
                          controller: _currentPasswordController,
                          label: 'Aktuelles Passwort',
                          prefixIcon: Icons.lock_outline,
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),

                        _buildStyledTextField(
                          controller: _newPasswordController,
                          label: 'Neues Passwort',
                          prefixIcon: Icons.lock,
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),

                        // NEU: Passwort bestätigen
                        _buildStyledTextField(
                          controller: _confirmPasswordController,
                          label: 'Neues Passwort bestätigen',
                          prefixIcon: Icons.lock_reset,
                          obscureText: true,
                        ),
                      ],

                      const SizedBox(height: 40),

                      // ==================== 5. BUTTONS ====================
                      if (_isEditing) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(
                              _isSaving
                                  ? 'Wird gespeichert...'
                                  : 'Änderungen speichern',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: _isSaving
                                ? null
                                : _confirmAndUpdateProfile,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      const Divider(),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: BorderSide(color: Colors.red.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text(
                            'Abmelden',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: _logout,
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
