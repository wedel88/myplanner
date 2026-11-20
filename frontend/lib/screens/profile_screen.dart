import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import 'project_grid_screen.dart';
import 'user_dashboard_screen.dart';

import 'package:image_picker/image_picker.dart';

import 'dart:typed_data';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false; // Steuert, ob Felder bearbeitbar sind
  Map<String, dynamic> _userData = {};
  String _errorMessage = '';

  // Controller für die bearbeitbaren Felder
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  // Controller für Passwort-Änderung
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

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

  // Sicherheitsabfrage (Ja/Nein Dialog) vor dem Speichern
  Future<void> _confirmAndUpdateProfile() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
        Uri.parse('http://127.0.0.1:8000/api/profile'), // Laravel-Endpunkt
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
        setState(() {
          _isEditing = false; // Bearbeitungsmodus beenden
        });
        _currentPasswordController.clear();
        _newPasswordController.clear();
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

  // 1. Bild auswählen und direkt als Bytes einlesen (ohne dart:io File)
  Future<void> _pickAndCropImage() async {
    final ImagePicker picker = ImagePicker();

    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400, // Maximale Breite
      maxHeight: 400, // Maximale Höhe
      imageQuality: 90,
    );

    if (pickedFile == null) return;

    // Bytes direkt auslesen (funktioniert im Web & auf Smartphones gleichermaßen)
    final bytes = await pickedFile.readAsBytes();
    await _uploadAvatarBytes(bytes);
  }

  // 2. Upload mit Bytes statt Dateipfad
  Future<void> _uploadAvatarBytes(Uint8List bytes) async {
    setState(() => _isSaving = true);
    try {
      final headers = await AuthService.getHeaders();
      headers.remove('Content-Type'); // Wichtig für Multipart-Request

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:8000/api/profile/avatar'),
      );
      request.headers.addAll(headers);

      // MultipartFile aus Bytes erstellen
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
        _fetchUserData(); // Profildaten neu laden, um das Bild anzuzeigen
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

  @override
  Widget build(BuildContext context) {
    // Avatar-URL ermitteln, falls vom Backend geliefert
    final userAvatarUrl = _userData['avatar'] != null
        ? 'http://127.0.0.1:8000/api/${_userData['avatar']}'
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mein Profil & Einstellungen'),
        actions: [
          // 🏠 1. Home / Projekt-Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: IconButton(
                tooltip: 'Projekte (Home)',
                icon: const Icon(
                  Icons.grid_view_rounded,
                  size: 20,
                  color: Colors.black87,
                ),
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const ProjectGridScreen()),
                  (route) => false,
                ),
              ),
            ),
          ),
          // 📊 2. Dashboard
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: IconButton(
                tooltip: 'Dashboard',
                icon: const Icon(
                  Icons.dashboard_outlined,
                  size: 20,
                  color: Colors.deepOrange,
                ),
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UserDashboardScreen(),
                  ),
                ),
              ),
            ),
          ),
          // 🔄 3. Aktualisieren
          Padding(
            padding: const EdgeInsets.only(
              left: 4.0,
              right: 12.0,
              top: 8.0,
              bottom: 8.0,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: IconButton(
                tooltip: 'Aktualisieren',
                icon: const Icon(
                  Icons.refresh,
                  size: 20,
                  color: Colors.black87,
                ),
                onPressed: _fetchUserData,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage.isNotEmpty
              ? Center(
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : ListView(
                  children: [
                    const SizedBox(height: 10),
                    // Avatar mit Upload-Option
                    // Beispiel für einen großen, sauberen Profilbild-Kreis:
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 120, // 👈 Hier kannst du die Größe des Kreises anpassen (z.B. 120x120)
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.blue, width: 3),
                              image: DecorationImage(
                                fit: BoxFit.cover, // 👈 Sorgt dafür, dass das Bild den Kreis perfekt ausfüllt
                                image:
                                    userAvatarUrl != null &&
                                        userAvatarUrl.isNotEmpty
                                    ? NetworkImage(userAvatarUrl)
                                          as ImageProvider
                                    : const AssetImage(
                                        'assets/default_avatar.png',
                                      ), // Fallback-Bild
                              ),
                            ),
                          ),
                          // Kamera-Icon zum Bearbeiten / Hochladen
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: _pickAndCropImage, // Deine Upload-Funktion
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
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
                    const SizedBox(height: 30),

                    // Feste System-Infos (User ID & Erstellungsdatum)
                    Card(
                      elevation: 0,
                      color: Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            ListTile(
                              dense: true,
                              title: const Text('Benutzer-ID (fest)'),
                              trailing: Text(
                                '${_userData['id'] ?? '-'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              dense: true,
                              title: const Text('Mitglied seit (fest)'),
                              trailing: Text(
                                _userData['created_at'] != null
                                    ? _userData['created_at']
                                          .toString()
                                          .substring(0, 10)
                                    : '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Kopfzeile mit Edit-Button Umschalter
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Persönliche Daten',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        TextButton.icon(
                          icon: Icon(
                            _isEditing ? Icons.close : Icons.edit,
                            size: 18,
                          ),
                          label: Text(_isEditing ? 'Abbrechen' : 'Bearbeiten'),
                          onPressed: () {
                            setState(() {
                              if (_isEditing) {
                                // Wenn abgebrochen wird, Originalwerte wiederherstellen
                                _nameController.text = _userData['name'] ?? '';
                                _emailController.text =
                                    _userData['email'] ?? '';
                                _currentPasswordController.clear();
                                _newPasswordController.clear();
                              }
                              _isEditing = !_isEditing;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Bearbeitbare Felder (nur aktiv wenn _isEditing == true)
                    TextField(
                      controller: _nameController,
                      enabled: _isEditing,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _emailController,
                      enabled: _isEditing,
                      decoration: const InputDecoration(
                        labelText: 'E-Mail-Adresse',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),

                    // Passwort-Felder nur im Bearbeitungsmodus anzeigen
                    if (_isEditing) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Passwort ändern (optional)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _currentPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Aktuelles Passwort',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _newPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Neues Passwort',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                        ),
                      ),
                    ],

                    const SizedBox(height: 30),

                    // Speichern Button (nur sichtbar im Bearbeitungsmodus)
                    if (_isEditing) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
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
                            style: const TextStyle(fontSize: 16),
                          ),
                          onPressed: _isSaving
                              ? null
                              : _confirmAndUpdateProfile,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    const Divider(),
                    const SizedBox(height: 10),

                    // Abmelden Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.logout),
                        label: const Text(
                          'Abmelden',
                          style: TextStyle(fontSize: 16),
                        ),
                        onPressed: _logout,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
        ),
      ),
    );
  }
}
