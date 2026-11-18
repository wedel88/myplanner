import 'package:material_ui/material_ui.dart';

class KanbanTaskCard extends StatefulWidget {
  final Map<String, dynamic> task;
  final Function(
    int taskId,
    String title,
    String desc,
    String status,
    String? dueAt,
  )
  onEdit;
  final Function(int taskId, String title) onDelete;
  final Function(int taskId) onAddSubtask;
  final Function(int subtaskId, bool currentStatus) onToggleSubtask;
  final Function(Map<String, dynamic> task) onManageSubtasks;

  const KanbanTaskCard({
    super.key,
    required this.task,
    required this.onEdit,
    required this.onDelete,
    required this.onAddSubtask,
    required this.onToggleSubtask,
    required this.onManageSubtasks,
  });

  @override
  State<KanbanTaskCard> createState() => _KanbanTaskCardState();
}

class _KanbanTaskCardState extends State<KanbanTaskCard> {
  bool _isExpanded = true; // Steuert, ob Subtasks angezeigt werden

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final taskId = int.tryParse(task['id']?.toString() ?? '') ?? 0;
    final taskTitle = task['title']?.toString() ?? 'Aufgabe';
    final taskDesc = task['description']?.toString() ?? '';
    final subtasks = (task['subtasks'] as List<dynamic>?) ?? [];
    final status = task['status']?.toString() ?? 'open';
    Color statusColor;
    if (status == 'completed') {
      statusColor = Colors.green;
    } else if (status == 'in_progress') {
      statusColor = Colors.orange;
    } else if (status == 'closed_incomplete') {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.blue; // 'open'
    }

    final dueAt = task['due_at']?.toString();
    String dueAtFormatted = '';
    bool isOverdue = false;

    if (dueAt != null && dueAt.isNotEmpty) {
      final date = DateTime.tryParse(dueAt);
      if (date != null) {
        dueAtFormatted =
            "Fällig: ${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";

        // Prüfen, ob das Datum in der Vergangenheit liegt und die Task noch nicht erledigt ist
        if (date.isBefore(DateTime.now()) && status != 'completed') {
          isOverdue = true;
        }
      }
    }

    // Die eigentliche Task-Card als Variable definieren
    final cardWidget = InkWell(
      onTap: () {
        // Öffnet den Bearbeiten-Dialog bei einem normalen Klick
        widget.onEdit(
          taskId,
          taskTitle,
          taskDesc,
          task['status']?.toString() ?? 'open',
          task['due_at']?.toString(), // NEU
        );
      },
      borderRadius: BorderRadius.circular(12), // Für den schönen Ripple-Effekt
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            // ... (Der Rest deiner Card bleibt exakt so wie er ist)
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Normaler Task-Header (Titel, Beschreibung, Menü)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(
                  // <-- NEU: Row statt Text
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        taskTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis, // Verhindert, dass zu lange Titel das Layout sprengen
                      ),
                    ),
                  ],
                ),
                subtitle: taskDesc.isNotEmpty ? Text(taskDesc) : null,
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    if (value == 'addSubtask') {
                      widget.onAddSubtask(taskId);
                    } else if (value == 'edit') {
                      widget.onEdit(
                        taskId,
                        taskTitle,
                        taskDesc,
                        task['status']?.toString() ?? 'open',
                        task['due_at']?.toString(), // NEU
                      );
                    } else if (value == 'delete') {
                      widget.onDelete(taskId, taskTitle);
                    } else if (value == 'manageSubtasks') {
                      widget.onManageSubtasks(task);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'addSubtask',
                      child: Row(
                        children: [
                          Icon(
                            Icons.playlist_add,
                            size: 18,
                            color: Colors.green,
                          ),
                          SizedBox(width: 8),
                          Text('Teilpunkt hinzufügen'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'manageSubtasks',
                      child: Row(
                        children: [
                          Icon(Icons.list_alt, size: 18, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Teilpunkte verwalten'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Bearbeiten'),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Löschen'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (dueAtFormatted.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, top: 4, bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: isOverdue ? Colors.red : Colors.grey, // NEU
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dueAtFormatted,
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverdue ? Colors.red : Colors.grey, // NEU
                          fontWeight: isOverdue
                              ? FontWeight.bold
                              : FontWeight.normal, // NEU
                        ),
                      ),
                    ],
                  ),
                ),
              // Sektion für Subtasks mit Ausklapp-Button
              if (subtasks.isNotEmpty) ...[
                const Divider(height: 12),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Teilpunkte (${subtasks.where((s) => s['is_completed'] == true || s['is_completed'] == 1).length}/${subtasks.length})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),

                // Wenn ausgeklappt, zeige die Liste
                if (_isExpanded) ...[
                  const SizedBox(height: 4),
                  ...subtasks.map((subtask) {
                    final subId =
                        int.tryParse(subtask['id']?.toString() ?? '') ?? 0;
                    final subTitle = subtask['title']?.toString() ?? '';
                    final isDone =
                        subtask['is_completed'] == true ||
                        subtask['is_completed'] == 1;

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDone
                            ? Colors.grey.shade100
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDone
                              ? Colors.green.shade200
                              : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () {
                              if (subId > 0) {
                                widget.onToggleSubtask(subId, isDone);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDone
                                    ? Colors.green
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isDone
                                      ? Colors.green
                                      : Colors.grey.shade400,
                                  width: 2,
                                ),
                              ),
                              child: isDone
                                  ? const Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (subId > 0) {
                                  widget.onToggleSubtask(subId, isDone);
                                }
                              },
                              child: Text(
                                subTitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  decoration: isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isDone
                                      ? Colors.grey.shade500
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ],
          ),
        ),
      ),
    );

    // Hier wird das Card-Widget wieder in das Draggable eingebettet
    return cardWidget;
  }
}
