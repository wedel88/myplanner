<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Subtask;
use Illuminate\Http\Request;

class SubtaskController extends Controller
{
    // Alle Subtasks abrufen (optional nach task_id filtern)
    public function index(Request $request)
    {
        $query = Subtask::query();

        if ($request->has('task_id')) {
            $query->where('task_id', $request->task_id);
        }

        return response()->json($query->get(), 200);
    }

    // Einen neuen Subtask erstellen
    public function store(Request $request)
    {
        $validated = $request->validate([
            'task_id' => 'required|exists:tasks,id',
            'title' => 'required|string|max:255',
            'is_completed' => 'nullable|boolean',
        ]);

        $subtask = Subtask::create($validated);

        return response()->json([
            'message' => 'Subtask erfolgreich erstellt!',
            'data' => $subtask
        ], 201);
    }

    // Einen Subtask aktualisieren (z.B. als erledigt markieren / abhaken)
    public function update(Request $request, Subtask $subtask)
    {
        $validated = $request->validate([
            'title' => 'sometimes|required|string|max:255',
            'is_completed' => 'sometimes|boolean',
        ]);

        $subtask->update($validated);

        return response()->json([
            'message' => 'Subtask aktualisiert',
            'data' => $subtask
        ], 200);
    }

    // Einen Subtask löschen
    public function destroy(Subtask $subtask)
    {
        $subtask->delete();
        return response()->json(['message' => 'Subtask gelöscht'], 200);
    }
}