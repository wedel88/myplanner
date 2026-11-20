import 'package:material_ui/material_ui.dart';

import '../services/auth_service.dart';
import 'project_grid_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isRegisterMode = false;
  bool _isLoading = false;

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) return;
    if (_isRegisterMode && name.isEmpty) return;

    setState(() => _isLoading = true);

    bool success;
    if (_isRegisterMode) {
      success = await AuthService.register(name, email, password);
    } else {
      success = await AuthService.login(email, password);
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProjectGridScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fehler bei der Anmeldung. Bitte prüfe deine Daten.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.task_alt, size: 80, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                _isRegisterMode ? 'Registrieren' : 'Willkommen zurück',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              if (_isRegisterMode)
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
              if (_isRegisterMode) const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-Mail',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Passwort',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isRegisterMode ? 'Konto erstellen' : 'Einloggen'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () =>
                    setState(() => _isRegisterMode = !_isRegisterMode),
                child: Text(
                  _isRegisterMode
                      ? 'Schon ein Konto? Hier einloggen.'
                      : 'Noch kein Konto? Hier registrieren.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
