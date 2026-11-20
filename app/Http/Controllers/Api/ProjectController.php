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
        $user = auth()->user();

        // Lade Projekte, die der User erstellt hat ODER in denen er Mitglied ist
        $projects = Project::where('user_id', $user->id)
            ->orWhereHas('users', function ($query) use ($user) {
                $query->where('users.id', $user->id);
            })
            ->get();

        return response()->json($projects, 200);
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
            ->with([
                'tasks' => function ($query) {
                    $query->orderBy('position');
                },
                'tasks.subtasks'
            ])
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
    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'description' => 'nullable|string',
        ]);

        // Projekt für den aktuellen User erstellen
        $project = auth()->user()->projects()->create($validated);

        // Den Ersteller automatisch als Mitglied hinzufügen
        $project->users()->attach(auth()->id());

        return response()->json($project, 201);
    }
    public function addMember(Request $request, Project $project)
    {
        // 1. Prüfen, ob der aktuelle User überhaupt Zugriff auf das Projekt hat
        $currentUser = auth()->user();
        $hasAccess = $project->user_id === $currentUser->id ||
            $project->users()->where('users.id', $currentUser->id)->exists();

        if (!$hasAccess) {
            return response()->json(['error' => 'Kein Zugriff auf dieses Projekt'], 403);
        }

        // 2. Die E-Mail des neuen Mitglieds validieren
        $request->validate([
            'email' => 'required|email|exists:users,email',
        ]);

        // 3. Den User anhand der E-Mail finden
        $newUser = \App\Models\User::where('email', $request->email)->first();

        // 4. Prüfen, ob der User schon Mitglied ist
        if ($project->users()->where('users.id', $newUser->id)->exists()) {
            return response()->json(['message' => 'Dieser User ist bereits Mitglied'], 400);
        }

        // 5. Den User zum Projekt hinzufügen
        $project->users()->attach($newUser->id);

        return response()->json(['message' => 'Mitglied erfolgreich hinzugefügt'], 200);
    }
    public function users(Project $project)
    {
        // Hole alle eingeladenen Mitglieder
        $users = $project->users;

        // Füge den Projekt-Ersteller (Owner) hinzu, falls vorhanden und noch nicht in der Liste
        if ($project->user_id) {
            $owner = \App\Models\User::find($project->user_id);
            if ($owner && !$users->contains('id', $owner->id)) {
                $users->push($owner);
            }
        }

        return response()->json($users);
    }
    public function projectUsers(Project $project)
    {
        return $project->users;
    }
}