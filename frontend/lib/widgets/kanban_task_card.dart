import 'package:material_ui/material_ui.dart';

class KanbanTaskCard extends StatefulWidget {
  final Map<String, dynamic> task;
  final String? forceStatus;
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
  final Function(Map<String, dynamic> taskData) onManageSubtasks;
  final VoidCallback onTap;
  final Function(int taskId, bool isReady) onToggleReady;

  const KanbanTaskCard({
    super.key,
    required this.task,
    this.forceStatus,
    required this.onEdit,
    required this.onDelete,
    required this.onAddSubtask,
    required this.onToggleSubtask,
    required this.onManageSubtasks,
    required this.onTap,
    required this.onToggleReady,
  });

  @override
  State<KanbanTaskCard> createState() => _KanbanTaskCardState();
}

class _KanbanTaskCardState extends State<KanbanTaskCard> {
  bool _isExpanded = false; // Für die Subtasks

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final taskId = int.tryParse(task['id']?.toString() ?? '') ?? 0;
    final title = task['title']?.toString() ?? 'Aufgabe';
    final description = task['description']?.toString() ?? '';
    final status = task['status']?.toString() ?? 'open';
    final dueAt = task['due_at']?.toString();
    final subtasks = (task['subtasks'] as List<dynamic>?) ?? [];
    // Wandelt 1, "1", true alles in einen echten bool um
    final bool isReady =
        task['is_ready'] == true ||
        task['is_ready'] == 1 ||
        task['is_ready'] == "1";

    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'in_progress':
        statusColor = Colors.orange;
        statusLabel = 'In Arbeit';
        break;
      case 'completed':
        statusColor = Colors.green;
        statusLabel = 'Erledigt';
        break;
      case 'closed_incomplete':
        statusColor = Colors.red;
        statusLabel = 'Abgebrochen';
        break;
      default:
        statusColor = Colors.blue;
        statusLabel = 'Offen';
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (value) {
                      if (value == 'edit') {
                        widget.onEdit(
                          taskId,
                          title,
                          description,
                          status,
                          dueAt,
                        );
                      } else if (value == 'delete') {
                        widget.onDelete(taskId, title);
                      } else if (value == 'subtask') {
                        widget.onAddSubtask(taskId);
                      } else if (value == 'manage_subtasks') {
                        widget.onManageSubtasks(task);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Bearbeiten'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Löschen'),
                      ),
                      const PopupMenuItem(
                        value: 'subtask',
                        child: Text('Teilpunkt hinzufügen'),
                      ),
                      if (subtasks.isNotEmpty)
                        const PopupMenuItem(
                          value: 'manage_subtasks',
                          child: Text('Teilpunkte verwalten'),
                        ),
                    ],
                  ),
                ],
              ),

              // 2. Beschreibung
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // 3. Aufklappbare Subtasks
              if (subtasks.isNotEmpty) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${subtasks.where((s) => s['is_completed'] == true).length}/${subtasks.length} Teilpunkte',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isExpanded) ...[
                  const SizedBox(height: 4),
                  ...subtasks.map((subtask) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: subtask['is_completed'] == true,
                              activeColor: Colors.blue,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onChanged: (val) {
                                if (val != null) {
                                  widget.onToggleSubtask(
                                    subtask['id'],
                                    subtask['is_completed'] == true,
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              subtask['title'] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                decoration: subtask['is_completed'] == true
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: subtask['is_completed'] == true
                                    ? Colors.grey
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],

              const SizedBox(height: 12),

              // 4. Footer (Status, Subtasks, Deadline, Ready-Icon)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      if (dueAt != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dueAt.split('T').first,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // NEU: Das "Bereit"-Häkchen
                  if (widget.forceStatus != null)
                    InkWell(
                      onTap: () => widget.onToggleReady(taskId, !isReady),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          isReady
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: isReady ? Colors.green : Colors.grey.shade400,
                          size: 22,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
