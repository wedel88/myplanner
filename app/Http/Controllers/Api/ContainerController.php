<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Container;
use App\Models\Project;
use Illuminate\Http\Request;

class ContainerController extends Controller
{
    // Alle Container eines Projekts auflisten
    public function index(Request $request)
    {
        // Man kann optional nach project_id filtern: /api/containers?project_id=1
        $query = Container::query();

        if ($request->has('project_id')) {
            $query->where('project_id', $request->project_id);
        }

        return response()->json($query->with('tasks')->orderBy('position')->get(), 200);
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
}