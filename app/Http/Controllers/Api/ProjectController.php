<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Project;
use Illuminate\Http\Request;

class ProjectController extends Controller
{
    // Alle Projekte abrufen
    public function index()
    {
        // Sortiert die Projekte automatisch nach sort_order aufsteigend
        return response()->json(Project::orderBy('sort_order')->get(), 200);
    }

    // Ein neues Projekt erstellen
    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255', // statt 'title'
            'description' => 'nullable|string',
        ]);

        $project = Project::create($validated);

        return response()->json([
            'message' => 'Projekt erfolgreich erstellt!',
            'data' => $project
        ], 201);
    }

    // Ein einzelnes Projekt mit Containern und Aufgaben anzeigen
    public function show(Project $project)
    {
        // Wir laden die Container und Aufgaben direkt mit (Eager Loading)
        return response()->json($project->load('containers.tasks'), 200);
    }

    // Ein Projekt löschen
    public function destroy(Project $project)
    {
        $project->delete();
        return response()->json(['message' => 'Projekt gelöscht'], 200);
    }
        public function getContainersWithTasks(Project $project)
    {
        $containers = $project->containers()
            ->orderBy('position')
            ->with(['tasks' => function ($query) {
                $query->orderBy('position');
            }, 'tasks.subtasks'])
            ->get();

        return response()->json($containers, 200);
    }
    // Ein bestehendes Projekt aktualisieren (Bearbeiten)
    public function update(Request $request, Project $project)
    {
        $validated = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'description' => 'nullable|string',
            'sort_order' => 'sometimes|integer'
        ]);

        $project->update($validated);

        return response()->json([
            'message' => 'Projekt erfolgreich aktualisiert!',
            'data' => $project
        ], 200);
    }

    // Projekte neu sortieren (für die manuelle Priorisierung per Drag & Drop)
    public function reorder(Request $request)
    {
        $request->validate([
            'project_ids' => 'required|array',
            'project_ids.*' => 'exists:projects,id'
        ]);

        foreach ($request->project_ids as $index => $projectId) {
            Project::where('id', $projectId)->update(['sort_order' => $index]);
        }

        return response()->json([
            'message' => 'Reihenfolge erfolgreich aktualisiert!'
        ], 200);
    }
}