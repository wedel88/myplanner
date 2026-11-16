import 'package:material_ui/material_ui.dart';

class KanbanTaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final Function(int taskId, String title, String desc) onEdit;
  final Function(int taskId, String title) onDelete;
  final Function(int taskId) onAddSubtask;
  final Function(int subtaskId, bool currentStatus) onToggleSubtask;

  const KanbanTaskCard({
    super.key,
    required this.task,
    required this.onEdit,
    required this.onDelete,
    required this.onAddSubtask,
    required this.onToggleSubtask,
  });

  @override
  Widget build(BuildContext context) {
    final taskId = int.tryParse(task['id']?.toString() ?? '') ?? 0;
    final taskTitle = task['title']?.toString() ?? 'Aufgabe';
    final taskDesc = task['description']?.toString() ?? '';
    final subtasks = (task['subtasks'] as List<dynamic>?) ?? [];

    return Draggable<Map<String, dynamic>>(
      data: task,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        elevation: 4.0,
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(12),
          color: Colors.blue,
          child: Text(
            taskTitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: Card(
          child: ListTile(
            title: Text(taskTitle),
            subtitle: taskDesc.isNotEmpty ? Text(taskDesc) : null,
          ),
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  taskTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: taskDesc.isNotEmpty ? Text(taskDesc) : null,
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    if (value == 'addSubtask') {
                      onAddSubtask(taskId);
                    } else if (value == 'edit') {
                      onEdit(taskId, taskTitle, taskDesc);
                    } else if (value == 'delete') {
                      onDelete(taskId, taskTitle);
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
              if (subtasks.isNotEmpty) ...[
                const Divider(height: 1),
                const SizedBox(height: 4),
                const Text(
                  'Teilpunkte:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                ...subtasks.map((subtask) {
                  final subId =
                      int.tryParse(subtask['id']?.toString() ?? '') ?? 0;
                  final subTitle = subtask['title']?.toString() ?? '';
                  final isDone =
                      subtask['is_completed'] == true ||
                      subtask['is_completed'] == 1;

                  return SizedBox(
                    height: 32,
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        subTitle,
                        style: TextStyle(
                          fontSize: 13,
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : null,
                          color: isDone ? Colors.grey : Colors.black87,
                        ),
                      ),
                      value: isDone,
                      onChanged: (val) {
                        if (subId > 0) {
                          onToggleSubtask(subId, isDone);
                        }
                      },
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
