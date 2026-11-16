import 'package:material_ui/material_ui.dart'; // Enthält bereits die Localizations

import 'screens/project_list_screen.dart';

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
      // NEU: Nutze die Aggregat-Eigenschaft aus material_ui
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('de'), Locale('en')],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ProjectListScreen(),
    );
  }
}
