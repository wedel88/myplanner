import 'package:material_ui/material_ui.dart';

import 'kanban_task_card.dart';

class KanbanContainerWidget extends StatelessWidget {
  final Map<String, dynamic> container;
  final int index;
  final bool isReorderable;
  final Function(Map<String, dynamic> task, int containerId) onTaskDropped;
  final Function(int containerId) onCreateTask;
  final Function(int containerId, String name) onEditContainer;
  final Function(int containerId, String name) onDeleteContainer;
  final Function(Map<String, dynamic> task) onManageSubtasks; // <--- HIER NEU

  // Weitergeleitete Callbacks für die Tasks
  final Function(int taskId, String title, String desc) onEditTask;
  final Function(int taskId, String title) onDeleteTask;
  final Function(int taskId) onAddSubtask;
  final Function(int subtaskId, bool currentStatus) onToggleSubtask;

  const KanbanContainerWidget({
    super.key,
    required this.container,
    required this.index,
    required this.isReorderable,
    required this.onTaskDropped,
    required this.onCreateTask,
    required this.onEditContainer,
    required this.onDeleteContainer,
    required this.onEditTask,
    required this.onDeleteTask,
    required this.onAddSubtask,
    required this.onToggleSubtask,
    required this.onManageSubtasks, // <--- HIER NEU
  });

  @override
  Widget build(BuildContext context) {
    final tasks = (container['tasks'] as List<dynamic>?) ?? [];
    final containerId = int.tryParse(container['id']?.toString() ?? '') ?? 0;
    final containerName = container['name']?.toString() ?? 'Spalte';

    return DragTarget<Map<String, dynamic>>(
      key: ValueKey('container_$containerId'),
      onAcceptWithDetails: (details) {
        onTaskDropped(details.data, containerId);
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 300,
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty
                ? Colors.blue.shade100
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isReorderable)
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.only(right: 6.0),
                        child: Icon(Icons.drag_indicator, color: Colors.grey),
                      ),
                    ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        containerName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Aufgabe hinzufügen',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => onCreateTask(containerId),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEditContainer(containerId, containerName);
                      } else if (value == 'delete') {
                        onDeleteContainer(containerId, containerName);
                      }
                    },
                    itemBuilder: (BuildContext context) => [
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
                ],
              ),
              const Divider(),
              Expanded(
                child: tasks.isEmpty
                    ? const Center(
                        child: Text(
                          'Noch keine Aufgaben',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: tasks.length,
                        itemBuilder: (context, taskIndex) {
                          final task = tasks[taskIndex] as Map<String, dynamic>;
                          return KanbanTaskCard(
                            task: task,
                            onEdit: onEditTask,
                            onDelete: onDeleteTask,
                            onAddSubtask: onAddSubtask,
                            onToggleSubtask: onToggleSubtask,
                            onManageSubtasks: onManageSubtasks,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
