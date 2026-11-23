import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';

import '../main.dart';
import '../services/auth_service.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<dynamic> _tasks = [];
  List<dynamic> _projects = [];
  List<dynamic> _groups = [];
  int? _currentUserId;

  // Filter-Variablen
  int? _selectedProjectId;
  int? _selectedGroupId;
  bool _showOnlyMyTasks = false;

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  Future<void> _initDashboard() async {
    _currentUserId = await AuthService.getCurrentUserId();
    await _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final headers = await AuthService.getHeaders();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/dashboard/tasks'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _stats = data['stats'] ?? {};
          _tasks = data['tasks'] ?? [];
          _projects = data['projects'] ?? [];
          _groups = data['groups'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Fehler beim Laden des Dashboards: $e');
      setState(() => _isLoading = false);
    }
  }

  // Filter-Logik
  List<dynamic> get _filteredTasks {
    return _tasks.where((task) {
      final project = task['container']?['project'];
      final projectId = project?['id'];
      final groupId = project?['group']?['id'];
      final assignedUserId = task['assigned_user_id'];

      bool matchesProject =
          _selectedProjectId == null || projectId == _selectedProjectId;
      bool matchesGroup =
          _selectedGroupId == null || groupId == _selectedGroupId;
      bool matchesMe = !_showOnlyMyTasks || assignedUserId == _currentUserId;

      return matchesProject && matchesGroup && matchesMe;
    }).toList();
  }

  // Statistiken basierend auf den gefilterten Tasks
  Map<String, int> get _filteredStats {
    final filtered = _filteredTasks;
    final now = DateTime.now();
    return {
      'total': filtered.length,
      'completed': filtered.where((t) => t['status'] == 'completed').length,
      'pending': filtered.where((t) => t['status'] != 'completed').length,
      'overdue': filtered.where((t) {
        if (t['status'] == 'completed' || t['due_at'] == null) return false;
        return DateTime.parse(t['due_at']).isBefore(now);
      }).length,
    };
  }

  // --- DESIGN BAUSTEINE ---
  Widget _buildStatCard(
    String title,
    int value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Icon(icon, color: color, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required int? value,
    required List<dynamic> items,
    required Function(int?) onChanged,
  }) {
    return Expanded(
      child: DropdownButtonFormField<int?>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
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
          const DropdownMenuItem<int?>(value: null, child: Text('Alle')),
          ...items.map(
            (item) => DropdownMenuItem<int?>(
              value: item['id'],
              child: Text(item['name'] ?? '', overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  // ==================== POPUP 1: GESAMT (TORTEN-DIAGRAMM) ====================
  void _showTotalPieChart() {
    final stats = _filteredStats;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Aufgaben-Verteilung',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 400,
          height: 300,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 60,
              sections: [
                PieChartSectionData(
                  value: stats['completed']!.toDouble(),
                  color: Colors.green,
                  title: '${stats['completed']}',
                  radius: 50,
                  titleStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                PieChartSectionData(
                  value: stats['pending']!.toDouble(),
                  color: Colors.orange,
                  title: '${stats['pending']}',
                  radius: 50,
                  titleStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                PieChartSectionData(
                  value: stats['overdue']!.toDouble(),
                  color: Colors.red,
                  title: '${stats['overdue']}',
                  radius: 50,
                  titleStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
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

  // ==================== POPUP 2: ERLEDIGT (BALKEN-DIAGRAMM) ====================
  void _showCompletedBarChart() {
    String timeRange = '7_days';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          // 1. Daten für das Chart berechnen (basierend auf _filteredTasks)
          final chartData = _calculateChartData(timeRange);

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Erledigte Aufgaben',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 500,
              height: 350,
              child: Column(
                children: [
                  // Zeitraum-Auswahl
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'yesterday', label: Text('Gestern')),
                      ButtonSegment(value: 'today', label: Text('Heute')),
                      ButtonSegment(value: '7_days', label: Text('7 Tage')),
                      ButtonSegment(value: 'month', label: Text('Monat')),
                    ],
                    selected: {timeRange},
                    onSelectionChanged: (Set<String> newSelection) {
                      setStateDialog(() => timeRange = newSelection.first);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Das Chart
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        barGroups: chartData.asMap().entries.map((entry) {
                          int index = entry.key;
                          var item = entry.value;
                          double value = (item['value'] ?? 0).toDouble();
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: value,
                                color: Colors.green,
                                width: 16,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          );
                        }).toList(),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) => Text(
                                value.toInt().toString(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                int idx = value.toInt();
                                if (idx >= 0 && idx < chartData.length) {
                                  return Text(
                                    chartData[idx]['label'],
                                    style: const TextStyle(fontSize: 10),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Schließen'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Hilfsfunktion zur Berechnung der Chart-Daten (alles lokal im Frontend!)
  List<Map<String, dynamic>> _calculateChartData(String range) {
    final now = DateTime.now();
    final completedTasks = _filteredTasks
        .where((t) => t['status'] == 'completed')
        .toList();
    List<Map<String, dynamic>> result = [];

    if (range == 'yesterday') {
      final yesterday = now.subtract(const Duration(days: 1));
      int count = completedTasks.where((t) {
        if (t['updated_at'] == null) return false;
        final date = DateTime.parse(t['updated_at']);
        return date.year == yesterday.year &&
            date.month == yesterday.month &&
            date.day == yesterday.day;
      }).length;
      result.add({'label': 'Gestern', 'value': count});
    } else if (range == 'today') {
      // Stunden 0 bis 23
      for (int i = 0; i < 24; i++) {
        int count = completedTasks.where((t) {
          if (t['updated_at'] == null) return false;
          final date = DateTime.parse(t['updated_at']);
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day &&
              date.hour == i;
        }).length;
        // Zeige nur jede 4. Stunde auf der Achse
        result.add({'label': i % 4 == 0 ? '$i:00' : '', 'value': count});
      }
    } else if (range == '7_days') {
      // Letzte 7 Tage
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        int count = completedTasks.where((t) {
          if (t['updated_at'] == null) return false;
          final d = DateTime.parse(t['updated_at']);
          return d.year == date.year &&
              d.month == date.month &&
              d.day == date.day;
        }).length;
        result.add({'label': '${date.day}.${date.month}.', 'value': count});
      }
    } else if (range == 'month') {
      // Letzte 30 Tage (zusammengefasst in 5-Tage-Blöcke für bessere Lesbarkeit)
      for (int i = 4; i >= 0; i--) {
        final start = now.subtract(Duration(days: (i * 6) + 5));
        final end = now.subtract(Duration(days: i * 6));
        int count = completedTasks.where((t) {
          if (t['updated_at'] == null) return false;
          final d = DateTime.parse(t['updated_at']);
          return d.isAfter(start) &&
              d.isBefore(end.add(const Duration(days: 1)));
        }).length;
        result.add({'label': '${start.day}.${start.month}.', 'value': count});
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _fetchDashboardData,
            tooltip: 'Aktualisieren',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 1000 : double.infinity,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ==================== 1. FILTER ====================
                      Row(
                        children: [
                          _buildDropdown(
                            label: 'Projekt',
                            value: _selectedProjectId,
                            items: _projects,
                            onChanged: (val) =>
                                setState(() => _selectedProjectId = val),
                          ),
                          const SizedBox(width: 12),
                          _buildDropdown(
                            label: 'Gruppe',
                            value: _selectedGroupId,
                            items: _groups,
                            onChanged: (val) =>
                                setState(() => _selectedGroupId = val),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  'Nur meine Aufgaben',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Switch(
                                  value: _showOnlyMyTasks,
                                  activeColor: Colors.blue,
                                  onChanged: (val) =>
                                      setState(() => _showOnlyMyTasks = val),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ==================== 2. STATISTIK KARTEN ====================
                      Row(
                        children: [
                          // Klick öffnet das Torten-Diagramm
                          _buildStatCard(
                            'Gesamt',
                            _filteredStats['total']!,
                            Icons.list_alt,
                            Colors.blue,
                            onTap: _showTotalPieChart,
                          ),
                          const SizedBox(width: 12),
                          // Nicht klickbar
                          _buildStatCard(
                            'Offen',
                            _filteredStats['pending']!,
                            Icons.pending_actions,
                            Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          // Klick öffnet das Balken-Diagramm
                          _buildStatCard(
                            'Erledigt',
                            _filteredStats['completed']!,
                            Icons.check_circle,
                            Colors.green,
                            onTap: _showCompletedBarChart,
                          ),
                          const SizedBox(width: 12),
                          // Nicht klickbar
                          _buildStatCard(
                            'Überfällig',
                            _filteredStats['overdue']!,
                            Icons.warning_amber_rounded,
                            Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // ==================== 3. TASK LISTE ====================
                      const Text(
                        'Anstehende Aufgaben',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _filteredTasks.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Center(
                                child: Text(
                                  'Keine Aufgaben für diesen Filter gefunden.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _filteredTasks.length,
                              itemBuilder: (context, index) {
                                final task = _filteredTasks[index];
                                final isCompleted =
                                    task['status'] == 'completed';
                                final isOverdue =
                                    !isCompleted &&
                                    task['due_at'] != null &&
                                    DateTime.parse(task['due_at'])
                                        .isBefore(DateTime.now());

                                return Card(
                                  elevation: 0,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: ListTile(
                                    leading: Icon(
                                      isCompleted
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      color: isCompleted
                                          ? Colors.green
                                          : (isOverdue
                                                ? Colors.red
                                                : Colors.grey),
                                    ),
                                    title: Text(
                                      task['title'] ?? 'Aufgabe',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        decoration: isCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: isCompleted
                                            ? Colors.grey
                                            : Colors.black87,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Projekt: ${task['container']?['project']?['name'] ?? 'Unbekannt'}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: isOverdue
                                        ? const Icon(
                                            Icons.warning,
                                            color: Colors.red,
                                          )
                                        : Text(
                                            task['due_at'] != null
                                                ? task['due_at']
                                                      .toString()
                                                      .substring(0, 10)
                                                : '',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
