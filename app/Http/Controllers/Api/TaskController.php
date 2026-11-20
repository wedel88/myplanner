<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Task;
use Illuminate\Http\Request;

class TaskController extends Controller
{
    // Alle Aufgaben abrufen (optional nach Container filtern)
    public function index(Request $request)
    {
        // 1. Vor dem Laden: Prüfe alle Tasks, die abgelaufen sind und noch nicht geschlossen wurden
        Task::whereNotNull('due_at')
            ->where('due_at', '<', now())
            ->whereNotIn('status', ['completed', 'closed_incomplete'])
            ->update(['status' => 'closed_incomplete']);

        // 2. Jetzt laden wir die (aktualisierten) Tasks
        $query = Task::query();
        if ($request->has('container_id')) {
            $query->where('container_id', $request->container_id);
        }

        return response()->json($query->with('subtasks', 'comments')->get(), 200);
    }

    // Eine neue Aufgabe erstellen
    public function store(Request $request)
    {
        $validated = $request->validate([
            'container_id' => 'required|exists:containers,id',
            'title' => 'required|string|max:255',
            'description' => 'nullable|string',
            'status' => 'nullable|in:open,in_progress,completed,closed_incomplete',
            'planned_start_at' => 'nullable|date', // <-- NEU
            'planned_end_at' => 'nullable|date',   // <-- NEU
            'due_at' => 'nullable|date',
        ]);

        $task = Task::create($validated);

        return response()->json([
            'message' => 'Aufgabe erfolgreich erstellt!',
            'data' => $task->load('subtasks')
        ], 201);
    }

    // Eine einzelne Aufgabe anzeigen (inklusive Subtasks und Kommentaren)
    public function show(Task $task)
    {
        return response()->json($task->load('subtasks', 'comments'), 200);
    }

    // Eine Aufgabe aktualisieren (z.B. Status ändern oder Verschieben in andere Spalte)
        public function update(Request $request, Task $task)
    {
        $validated = $request->validate([
            'container_id' => 'sometimes|exists:containers,id',
            'title' => 'sometimes|required|string|max:255',
            'description' => 'nullable|string',
            'status' => 'sometimes|in:open,in_progress,completed,closed_incomplete',
            'planned_start_at' => 'nullable|date', // <-- NEU
            'planned_end_at' => 'nullable|date',   // <-- NEU
            'due_at' => 'nullable|date',
            'assigned_user_id' => 'nullable|exists:users,id',
        ]);

        $task->update($validated);

        return response()->json([
            'message' => 'Aufgabe aktualisiert',
            'data' => $task->load('subtasks'),
            $task->load('assignedUser')
        ], 200);
    }

    // Eine Aufgabe löschen
    public function destroy(Task $task)
    {
        $task->delete();
        return response()->json(['message' => 'Aufgabe gelöscht'], 200);
    }
    public function move(Request $request, Task $task)
    {
        $request->validate([
            'container_id' => 'required|exists:containers,id',
            'position' => 'nullable|integer', // Optional: Die genaue Zielposition
        ]);

        $targetContainerId = $request->container_id;
        $newPosition = $request->position ?? 0;

        // Aktualisiere Container und Position der verschobenen Task
        $task->update([
            'container_id' => $targetContainerId,
            'position' => $newPosition,
        ]);

        return response()->json(['message' => 'Task erfolgreich verschoben']);
    }
    // In TaskController.php hinzufügen:
    public function reorder(Request $request, Task $task)
    {
        $validated = $request->validate([
            'container_id' => 'required|exists:containers,id',
            'position' => 'required|integer',
        ]);

        $task->container_id = $validated['container_id'];
        $task->position = $validated['position'];
        $task->save();

        return response()->json(['message' => 'Task Position gespeichert']);
    }
}