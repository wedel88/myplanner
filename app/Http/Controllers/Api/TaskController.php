<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Task;
use App\Models\Container;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class TaskController extends Controller
{
    // Hilfsmethode: Prüft, ob der User Zugriff auf das Projekt der Task hat
    private function hasProjectAccess($projectId)
    {
        $user = Auth::user();
        if (!$user)
            return false;

        return \App\Models\Project::where('id', $projectId)
            ->where(function ($query) use ($user) {
                $query->where('user_id', $user->id)
                    ->orWhereHas('users', function ($q) use ($user) {
                        $q->where('users.id', $user->id);
                    });
            })->exists();
    }

    // Hilfsmethode: Holt die Projekt-ID über die Container-ID
    private function getProjectIdFromContainer($containerId)
    {
        $container = Container::find($containerId);
        return $container ? $container->project_id : null;
    }

    // Alle Aufgaben abrufen
    public function index(Request $request)
    {
        // 1. Abgelaufene Tasks prüfen (unverändert)
        Task::whereNotNull('due_at')
            ->where('due_at', '<', now())
            ->whereNotIn('status', ['completed', 'closed_incomplete'])
            ->update(['status' => 'closed_incomplete']);

        // 2. Tasks laden
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
            'is_ready' => 'sometimes|boolean',
            'planned_start_at' => 'nullable|date',
            'planned_end_at' => 'nullable|date',
            'due_at' => 'nullable|date',
            'assigned_user_id' => 'nullable|exists:users,id', // NEU: Zuweisung erlauben
        ]);

        // SICHERHEIT: Darf der User in dieses Projekt schreiben?
        $projectId = $this->getProjectIdFromContainer($validated['container_id']);
        if (!$projectId || !$this->hasProjectAccess($projectId)) {
            return response()->json(['message' => 'Kein Zugriff auf dieses Projekt.'], 403);
        }

        // Force-Status der Spalte anwenden
        $container = Container::find($validated['container_id']);
        if ($container && $container->force_status) {
            $validated['status'] = $container->force_status;
        } else if (!isset($validated['status'])) {
            $validated['status'] = 'open';
        }

        if (!isset($validated['is_ready'])) {
            $validated['is_ready'] = false;
        }
        if (!isset($validated['due_at'])) {
            $projectId = $container->project_id;
            $project = \App\Models\Project::find($projectId);
            if ($project && $project->due_at) {
                $validated['due_at'] = $project->due_at;
            }
        }

        $task = Task::create($validated);

        return response()->json([
            'message' => 'Aufgabe erfolgreich erstellt!',
            'data' => $task->load('subtasks')
        ], 201);
    }

    // Eine einzelne Aufgabe anzeigen
    public function show(Task $task)
    {
        // SICHERHEIT: Prüfen, ob User Zugriff auf das Projekt hat
        $projectId = $task->container->project_id;
        if (!$this->hasProjectAccess($projectId)) {
            return response()->json(['message' => 'Kein Zugriff auf diese Aufgabe.'], 403);
        }

        return response()->json($task->load('subtasks', 'comments', 'attachments'), 200);
    }

    // Eine Aufgabe aktualisieren (z.B. Häkchen setzen)
    public function update(Request $request, Task $task)
    {
        // SICHERHEIT: Prüfen, ob User Zugriff auf das Projekt hat
        $projectId = $task->container->project_id;
        if (!$this->hasProjectAccess($projectId)) {
            return response()->json(['message' => 'Kein Zugriff auf diese Aufgabe.'], 403);
        }

        $validated = $request->validate([
            'container_id' => 'sometimes|exists:containers,id',
            'title' => 'sometimes|required|string|max:255',
            'description' => 'nullable|string',
            'status' => 'sometimes|in:open,in_progress,completed,closed_incomplete',
            'is_ready' => 'sometimes|boolean',
            'planned_start_at' => 'nullable|date',
            'planned_end_at' => 'nullable|date',
            'due_at' => 'nullable|date',
            'assigned_user_id' => 'nullable|exists:users,id',
            'recurrence' => 'sometimes|string|in:none,daily,weekly,monthly',
            'recurrence_day_of_week' => 'nullable|integer|between:1,7',
            'recurrence_day_of_month' => 'nullable|integer|between:1,31',
        ]);

        $task->update($validated);

        return response()->json([
            'message' => 'Aufgabe aktualisiert',
            'data' => $task->load('subtasks')
        ], 200);
    }

    // Eine Aufgabe löschen
    public function destroy(Task $task)
    {
        // SICHERHEIT: Prüfen, ob User Zugriff auf das Projekt hat
        $projectId = $task->container->project_id;
        if (!$this->hasProjectAccess($projectId)) {
            return response()->json(['message' => 'Kein Zugriff auf diese Aufgabe.'], 403);
        }

        $task->delete();
        return response()->json(['message' => 'Aufgabe gelöscht'], 200);
    }

    // Task verschieben (mit Force-Status und Reset des Häkchens)
    public function move(Request $request, Task $task)
    {
        // SICHERHEIT: Prüfen, ob User Zugriff auf das Projekt hat
        $projectId = $task->container->project_id;
        if (!$this->hasProjectAccess($projectId)) {
            return response()->json(['message' => 'Kein Zugriff auf diese Aufgabe.'], 403);
        }

        $request->validate([
            'container_id' => 'required|exists:containers,id',
            'position' => 'nullable|integer',
        ]);

        $targetContainerId = $request->container_id;
        $newPosition = $request->position ?? 0;

        $targetContainer = Container::find($targetContainerId);
        $newStatus = $task->status;

        if ($targetContainer && $targetContainer->force_status) {
            $newStatus = $targetContainer->force_status;
        }

        $task->update([
            'container_id' => $targetContainerId,
            'position' => $newPosition,
            'status' => $newStatus,
            'is_ready' => false, // WICHTIG: Häkchen zurücksetzen
        ]);

        // NEU: is_ready in die Antwort packen, damit das Frontend es sofort weiß
        return response()->json([
            'message' => 'Task verschoben',
            'new_status' => $newStatus,
            'is_ready' => false
        ]);
    }
}