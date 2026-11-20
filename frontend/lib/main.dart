import 'package:material_ui/material_ui.dart';

import 'screens/login_screen.dart';
import 'screens/project_grid_screen.dart';
import 'services/auth_service.dart';
import '/screens/profile_screen.dart';
import '/screens/user_dashboard_screen.dart';

// WICHTIG: Kein flutter_localizations Import mehr!

const String apiBaseUrl = 'http://127.0.0.1:8000/api';

void main() {
  runApp(const MyPlannerApp());
}

class MyPlannerApp extends StatelessWidget {
  const MyPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyPlanner',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('de'), Locale('en')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthCheckScreen(),
      // 👇 HIER MÜSSEN DIE ROUTEN REGISTRIERT WERDEN
      routes: {
        '/login': (context) => const LoginScreen(), // Ersetze 'LoginScreen' mit dem tatsächlichen Namen deiner Login-Klasse
        '/home': (context) => const ProjectGridScreen(),
        '/dashboard': (context) => const UserDashboardScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await AuthService.getToken();
    if (!mounted) return;

    if (token != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProjectGridScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
