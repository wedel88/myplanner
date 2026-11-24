import 'package:material_ui/material_ui.dart';

import 'kanban_task_card.dart';

class KanbanContainerWidget extends StatelessWidget {
  final Map<String, dynamic> container;
  final int index;
  final bool isReorderable;
  final Function(Map<String, dynamic> task, int containerId, int newPosition)
  onTaskDropped;
  final Function(int containerId) onCreateTask;
  final Function(int containerId, String name) onEditContainer;
  final Function(int containerId, String name) onDeleteContainer;
  final Function(
    int taskId,
    String title,
    String desc,
    String status,
    String? dueAt,
  )
  onEditTask;
  final Function(int taskId, String title) onDeleteTask;
  final Function(int taskId) onAddSubtask;
  final Function(int subtaskId, bool currentStatus) onToggleSubtask;
  final Function(Map<String, dynamic> taskData) onManageSubtasks;
  final Function(Map<String, dynamic> task) onTaskTap;
  final Function(int taskId, bool isReady) onToggleReady; // NEU
  final bool isReorderMode;

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
    required this.onManageSubtasks,
    required this.isReorderMode,
    required this.onTaskTap,
    required this.onToggleReady, // NEU
  });

  @override
  Widget build(BuildContext context) {
    final tasks = (container['tasks'] as List<dynamic>?) ?? [];
    final containerId = int.tryParse(container['id']?.toString() ?? '') ?? 0;
    final containerName = container['name']?.toString() ?? 'Spalte';
    final forceStatus = container['force_status'] as String?;

    return DragTarget<Map<String, dynamic>>(
      key: ValueKey('container_$containerId'),
      onAcceptWithDetails: (details) {
        final task = details.data;
        final taskId = int.tryParse(task['id']?.toString() ?? '') ?? 0;
        if (taskId > 0 && containerId > 0) {
          final newPosition = tasks.length;
          onTaskDropped(task, containerId, newPosition);
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 300,
          height: MediaQuery.of(context).size.height * 0.7,
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
              // Spalten-Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Der Name der Spalte bekommt flexiblen Platz
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          // <-- Verhindert den Overflow!
                          child: Text(
                            containerName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (forceStatus != null) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.lock_clock,
                            size: 16,
                            color: Colors.orange.shade700,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Die Buttons bleiben fest rechts
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                ],
              ),
              const Divider(),

              // Aufgabenliste
              Expanded(
                child: tasks.isEmpty
                    ? const Center(child: Text('Noch keine Aufgaben'))
                    : ListView.builder(
                        // Das ist der Trick für flüssiges Scrollen
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: tasks.length + 1,
                        itemBuilder: (context, taskIndex) {
                          if (taskIndex == tasks.length) {
                            return DragTarget<Map<String, dynamic>>(
                              onAcceptWithDetails: (details) {
                                if (!isReorderMode) {
                                  onTaskDropped(
                                    details.data,
                                    containerId,
                                    tasks.length,
                                  );
                                }
                              },
                              builder: (context, candidateData, rejectedData) {
                                return Container(
                                  height: 50,
                                  color: candidateData.isNotEmpty
                                      ? Colors.blue.shade100
                                      : Colors.transparent,
                                  child: candidateData.isNotEmpty
                                      ? const Center(
                                          child: Text(
                                            'Hier ablegen',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.blue,
                                            ),
                                          ),
                                        )
                                      : null,
                                );
                              },
                            );
                          }

                          final task = tasks[taskIndex] as Map<String, dynamic>;
                          final taskCard = KanbanTaskCard(
                            task: task,
                            forceStatus:
                                forceStatus, // NEU: An die Karte übergeben
                            onEdit: onEditTask,
                            onDelete: onDeleteTask,
                            onAddSubtask: onAddSubtask,
                            onToggleSubtask: onToggleSubtask,
                            onManageSubtasks: onManageSubtasks,
                            onTap: () => onTaskTap(task),
                            onToggleReady: onToggleReady, // NEU
                          );

                          if (isReorderMode) return taskCard;

                          return DragTarget<Map<String, dynamic>>(
                            onWillAcceptWithDetails: (details) =>
                                details.data['id'] != task['id'],
                            onAcceptWithDetails: (details) {
                              onTaskDropped(
                                details.data,
                                containerId,
                                taskIndex,
                              );
                            },
                            builder: (context, candidateData, rejectedData) {
                              final isHovering = candidateData.isNotEmpty;
                              return Column(
                                children: [
                                  if (isHovering)
                                    Container(height: 4, color: Colors.blue),
                                  LongPressDraggable<Map<String, dynamic>>(
                                    data: task,
                                    delay: const Duration(milliseconds: 150),
                                    feedback: Material(
                                      elevation: 6,
                                      color: Colors.transparent,
                                      child: SizedBox(
                                        width: 280,
                                        child: taskCard,
                                      ),
                                    ),
                                    childWhenDragging: Opacity(
                                      opacity: 0.4,
                                      child: taskCard,
                                    ),
                                    child: taskCard,
                                  ),
                                ],
                              );
                            },
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
