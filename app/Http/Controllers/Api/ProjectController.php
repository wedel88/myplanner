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
        return response()->json(Project::all(), 200);
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
    // HIER muss 'tasks.subtasks' mitgeladen werden:
    $containers = $project->containers()->with('tasks.subtasks')->orderBy('position')->get();

    return response()->json($containers, 200);
}
}