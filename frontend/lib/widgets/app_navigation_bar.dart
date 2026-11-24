import 'package:material_ui/material_ui.dart';

import '../screens/project_grid_screen.dart';
import '../screens/user_dashboard_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/group_management_screen.dart';
import '../screens/archived_projects_screen.dart';

class AppNavigationBar extends StatelessWidget implements PreferredSizeWidget {
  final String currentRoute;
  final List<Widget>? actions;

  const AppNavigationBar({super.key, required this.currentRoute, this.actions});

  @override
  Widget build(BuildContext context) {
    // Prüfen, ob wir auf einem Haupt-Screen sind. Wenn nicht, zeigen wir einen Zurück-Button.
    final isMainScreen = [
      '/home',
      '/dashboard',
      '/groups',
      '/profile',
      '/archive',
    ].contains(currentRoute);

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black87),

      // 1. LINKS: Zurück-Button (nur wenn wir nicht auf einem Haupt-Screen sind)
      leading: isMainScreen
          ? null
          : IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Zurück',
              onPressed: () => Navigator.pop(context),
            ),

      // 2. MITTE: Die Navigations-Buttons (Home, Dashboard, etc.)
      title: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildNavButton(
                context,
                'Home',
                Icons.grid_view_rounded,
                currentRoute == '/home',
                () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ProjectGridScreen()),
                ),
              ),
              _buildNavButton(
                context,
                'Dashboard',
                Icons.dashboard_outlined,
                currentRoute == '/dashboard',
                () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UserDashboardScreen(),
                  ),
                ),
              ),
              _buildNavButton(
                context,
                'Gruppen',
                Icons.group_outlined,
                currentRoute == '/groups',
                () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GroupManagementScreen(
                      apiBaseUrl: 'http://127.0.0.1:8000/api',
                    ),
                  ),
                ),
              ),
              _buildNavButton(
                context,
                'Profil',
                Icons.person_outline,
                currentRoute == '/profile',
                () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
            ],
          ),
        ),
      ),

      // 3. RECHTS: Zusätzliche Actions (z.B. Archiv, Info, etc.)
      actions: [
        // Archiv-Button (nur anzeigen, wenn wir NICHT auf dem Archiv-Screen sind)
        if (currentRoute != '/archive')
          IconButton(
            icon: const Icon(Icons.archive_outlined, color: Colors.orange),
            tooltip: 'Archivierte Projekte',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const ArchivedProjectsScreen(),
                ),
              );
            },
          ),

        // Zusätzliche Actions, die von den Screens übergeben werden (z.B. Projekt-Info)
        if (actions != null) ...actions!,

        const SizedBox(width: 8), // Abstand zum rechten Rand
      ],
    );
  }

  Widget _buildNavButton(
    BuildContext context,
    String label,
    IconData icon,
    bool isActive,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.blue : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isActive ? Colors.blue : Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
