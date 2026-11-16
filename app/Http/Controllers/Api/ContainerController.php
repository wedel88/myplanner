<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Container;
use App\Models\Project;
use Illuminate\Http\Request;

class ContainerController extends Controller
{
 public function index(Request $request)
    {
        $query = Container::query();

        if ($request->has('project_id')) {
        $query->where('project_id', $request->project_id);
        }

    // WICHTIG: Hier muss 'tasks.subtasks' stehen!
    return response()->json($query->with('tasks.subtasks')->orderBy('position')->get(), 200);
    }

    // Einen neuen Container (Spalte) erstellen
    public function store(Request $request)
    {
        $validated = $request->validate([
            'project_id' => 'required|exists:projects,id',
            'name' => 'required|string|max:255',
            'position' => 'nullable|integer',
        ]);

        $container = Container::create($validated);

        return response()->json([
            'message' => 'Container erfolgreich erstellt!',
            'data' => $container
        ], 201);
    }

    // Einen Container anzeigen (inklusive Aufgaben)
    public function show(Container $container)
    {
        return response()->json($container->load('tasks'), 200);
    }

    // Einen Container aktualisieren (z. B. Umbenennen)
    public function update(Request $request, Container $container)
    {
        $validated = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'position' => 'sometimes|integer',
        ]);

        $container->update($validated);

        return response()->json([
            'message' => 'Container aktualisiert',
            'data' => $container
        ], 200);
    }

    // Einen Container löschen
    public function destroy(Container $container)
    {
        $container->delete();
        return response()->json(['message' => 'Container gelöscht'], 200);
    }
    public function updatePosition(Request $request, $id)
{
    $container = Container::findOrFail($id);
    
    $validated = $request->validate([
        'position' => 'required|integer',
    ]);

    $container->position = $validated['position'];
    $container->save();

    return response()->json(['message' => 'Position aktualisiert'], 200);
}
}