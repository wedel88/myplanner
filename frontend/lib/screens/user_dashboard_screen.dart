import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';

import '../main.dart';
import '../services/auth_service.dart';
import '../widgets/app_navigation_bar.dart'; // Für die einheitliche Navigation

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
  bool _hideCompletedInList = false;

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
    if (mounted)
      setState(() => _isLoading = true); // Prüfen vor dem ersten setState

    try {
      final headers = await AuthService.getHeaders();
      final response = await http.get(
        Uri.parse('$apiBaseUrl/dashboard/tasks'),
        headers: headers,
      );

      if (!mounted) return; // Prüfen NACH der asynchronen Anfrage!

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
      if (mounted) setState(() => _isLoading = false); // Prüfen im Catch-Block
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

  List<Map<String, dynamic>> _calculateChartData(String range) {
    // (Unverändert aus deinem vorherigen Code)
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
      for (int i = 0; i < 24; i++) {
        int count = completedTasks.where((t) {
          if (t['updated_at'] == null) return false;
          final date = DateTime.parse(t['updated_at']);
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day &&
              date.hour == i;
        }).length;
        result.add({'label': i % 4 == 0 ? '$i:00' : '', 'value': count});
      }
    } else if (range == '7_days') {
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

  // ==================== WIDGETS FÜR DIE ZEITLINIE ====================

  Widget _buildTaskList({bool showCompleted = true}) {
    // 1. Aufgaben filtern (je nach Einstellung)
    final listToShow = showCompleted
        ? _filteredTasks
        : _filteredTasks.where((t) => t['status'] != 'completed').toList();

    if (listToShow.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
          child: Text(
            'Keine Aufgaben für diesen Filter gefunden.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: listToShow.length, // <-- Nutzt die gefilterte Liste
      itemBuilder: (context, index) {
        final task = listToShow[index]; // <-- Nutzt die gefilterte Liste
        // ... (Der Rest deiner Card-Logik bleibt komplett gleich!)
        final isCompleted = task['status'] == 'completed';
        final isOverdue =
            !isCompleted &&
            task['due_at'] != null &&
            DateTime.parse(task['due_at']).isBefore(DateTime.now());

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: Icon(
              isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isCompleted
                  ? Colors.green
                  : (isOverdue ? Colors.red : Colors.grey),
            ),
            title: Text(
              task['title'] ?? 'Aufgabe',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? Colors.grey : Colors.black87,
              ),
            ),
            subtitle: Text(
              'Projekt: ${task['container']?['project']?['name'] ?? 'Unbekannt'}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: isOverdue
                ? const Icon(Icons.warning, color: Colors.red)
                : Text(
                    task['due_at'] != null
                        ? task['due_at'].toString().substring(0, 10)
                        : '',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildTimeline() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 1. Aufgaben filtern: Nur Aufgaben mit Datum, die HEUTE oder in ZUKUNFT liegen (oder überfällig sind)
    final timelineTasks = _filteredTasks.where((task) {
      // Wir nehmen das relevanteste Datum (Ende oder Deadline)
      final dateStr = task['planned_end_at'] ?? task['due_at'];
      if (dateStr == null) return false;

      final date = DateTime.parse(dateStr);
      // Zeige nur Aufgaben, deren Datum heute oder in der Zukunft liegt
      return date.isAfter(today.subtract(const Duration(days: 1)));
    }).toList();

    if (timelineTasks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(
          child: Text(
            'Keine geplanten Aufgaben in der Zukunft.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // 2. Gruppieren nach Tag
    Map<DateTime, List<dynamic>> groupedTasks = {};

    for (var task in timelineTasks) {
      final dateStr = task['planned_end_at'] ?? task['due_at'];
      final date = DateTime.parse(dateStr);
      // Wir entfernen die Uhrzeit, damit wir nach Tagen gruppieren können
      final dayOnly = DateTime(date.year, date.month, date.day);

      if (!groupedTasks.containsKey(dayOnly)) {
        groupedTasks[dayOnly] = [];
      }
      groupedTasks[dayOnly]!.add(task);
    }

    // 3. Die Tage korrekt sortieren (Echte DateTime-Sortierung, nicht String!)
    final sortedDates = groupedTasks.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        final tasksForDate = groupedTasks[date]!;
        final dateLabel =
            "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 8),

              ...tasksForDate.map((task) {
                final dueDate = task['due_at'] != null
                    ? DateTime.parse(task['due_at'])
                    : null;
                final isOverdue =
                    dueDate != null &&
                    dueDate.isBefore(now) &&
                    task['status'] != 'completed';

                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8, left: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    leading: Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isOverdue ? Colors.red : Colors.blue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    title: Text(
                      task['title'] ?? 'Aufgabe',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task['container']?['project']?['name'] ?? 'Unbekannt',
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bis: ${dateLabel}', // Da wir nach dem relevantesten Datum gruppiert haben
                          style: TextStyle(
                            fontSize: 11,
                            color: isOverdue
                                ? Colors.red
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop =
        MediaQuery.of(context).size.width > 900; // Etwas höher für 2 Spalten

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: const AppNavigationBar(currentRoute: '/dashboard'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 1200 : double.infinity,
                ), // Breiter für 2 Spalten
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
                                  'Nur meine',
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
                          _buildStatCard(
                            'Gesamt',
                            _filteredStats['total']!,
                            Icons.list_alt,
                            Colors.blue,
                            onTap: _showTotalPieChart,
                          ),
                          const SizedBox(width: 12),
                          _buildStatCard(
                            'Offen',
                            _filteredStats['pending']!,
                            Icons.pending_actions,
                            Colors.orange,
                          ),
                          const SizedBox(width: 12),
                          _buildStatCard(
                            'Erledigt',
                            _filteredStats['completed']!,
                            Icons.check_circle,
                            Colors.green,
                            onTap: _showCompletedBarChart,
                          ),
                          const SizedBox(width: 12),
                          _buildStatCard(
                            'Überfällig',
                            _filteredStats['overdue']!,
                            Icons.warning_amber_rounded,
                            Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // ==================== 3. DIE ZWEI SPALTEN (Liste & Timeline) ====================
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Linke Spalte: Aufgaben
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header mit Toggle-Button
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Anstehende Aufgaben',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      // NEU: Der Toggle-Button
                                      IconButton(
                                        tooltip: _hideCompletedInList
                                            ? 'Erledigte anzeigen'
                                            : 'Erledigte ausblenden',
                                        icon: Icon(
                                          _hideCompletedInList
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: _hideCompletedInList
                                              ? Colors.grey
                                              : Colors.blue,
                                        ),
                                        onPressed: () {
                                          setState(
                                            () => _hideCompletedInList =
                                                !_hideCompletedInList,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Die Liste (gefiltert, wenn _hideCompletedInList true ist)
                                  _buildTaskList(
                                    showCompleted: !_hideCompletedInList,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 32),
                            // Rechte Spalte: Zeitplan
                            Expanded(
                              flex: 1,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Zeitplan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTimeline(),
                                ],
                              ),
                            ),
                          ],
                        )
                      else
                        // Mobile Ansicht (Untereinander)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Anstehende Aufgaben',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            IconButton(
                              tooltip: _hideCompletedInList
                                  ? 'Erledigte anzeigen'
                                  : 'Erledigte ausblenden',
                              icon: Icon(
                                _hideCompletedInList
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: _hideCompletedInList
                                    ? Colors.grey
                                    : Colors.blue,
                              ),
                              onPressed: () {
                                setState(
                                  () => _hideCompletedInList =
                                      !_hideCompletedInList,
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildTaskList(
                              showCompleted: !_hideCompletedInList,
                            ),
                            const SizedBox(height: 32),
                            const Text(
                              'Zeitplan',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildTimeline(),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
