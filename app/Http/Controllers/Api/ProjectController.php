<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Project;
use Illuminate\Http\Request;
use App\Models\Attachment;
use Illuminate\Support\Facades\Storage;

class ProjectController extends Controller
{
    // Alle Projekte abrufen
    public function index()
    {
        $user = auth()->user();

        $projects = Project::where('user_id', $user->id)
            ->orWhereHas('group', function ($query) use ($user) {
                $query->whereHas('users', function ($subQuery) use ($user) {
                    $subQuery->where('users.id', $user->id);
                });
            })
            ->with('group')
            ->get();

        return response()->json($projects, 200);
    }

    // Ein einzelnes Projekt mit Containern und Aufgaben anzeigen
    public function show(Project $project)
    {
        // Lädt das Projekt inklusive Gruppe, Anhängen und Tasks
        $project->load([
            'group',
            'attachments.user',
            'containers.tasks.attachments.user'
        ]);

        return response()->json($project, 200);
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
                'tasks.subtasks',
                'tasks.attachments.user'
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
            'sort_order' => 'sometimes|integer',
            'group_id' => 'nullable|exists:groups,id', // 👈 HIER HINZUFÜGEN
        ]);

        $project->update($validated);

        return response()->json([
            'message' => 'Projekt erfolgreich aktualisiert!',
            'data' => $project->load('group') // 👈 Lädt die Gruppe direkt mit
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
            'group_id' => 'nullable|exists:groups,id', // 👈 HIER HINZUFÜGEN
        ]);

        // Projekt für den aktuellen User erstellen (inklusive group_id falls mitgeschickt)
        $project = auth()->user()->projects()->create($validated);

        // Den Ersteller automatisch als Mitglied hinzufügen
        $project->users()->attach(auth()->id());

        return response()->json($project->load('group'), 201); // 👈 Optional: direkt mit Gruppe zurückgeben
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


    // 1. Alle Dateien eines Projekts auflisten (Projektweit + alle Tasks im Projekt)
    public function projectFiles($projectId)
    {
        // 1. Alle Task-IDs ermitteln, die zu diesem Projekt gehören
        $taskIds = \App\Models\Task::whereHas('container', function ($q) use ($projectId) {
            $q->where('project_id', $projectId);
        })->pluck('id');

        // 2. Alle Attachments einsammeln (Projektweit, direkte Tasks & via Chat/Kommentare)
        $attachments = Attachment::with(['user', 'task', 'comment'])
            ->where(function ($query) use ($projectId, $taskIds) {
                $query->where('project_id', $projectId)
                    ->orWhereIn('task_id', $taskIds)
                    ->orWhereHas('comment', function ($q) use ($projectId, $taskIds) {
                        $q->where(function ($sub) use ($projectId, $taskIds) {
                            $sub->where('commentable_type', 'App\Models\Project')
                                ->where('commentable_id', $projectId);
                        })->orWhere(function ($sub) use ($taskIds) {
                            $sub->where('commentable_type', 'App\Models\Task')
                                ->whereIn('commentable_id', $taskIds);
                        });
                    });
            })
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json($attachments, 200);
    }

    // 2. Einzelne Datei löschen
    public function destroyAttachment($id)
    {
        $attachment = Attachment::findOrFail($id);

        // Datei physisch aus dem Storage löschen
        if (Storage::disk('public')->exists($attachment->file_path)) {
            Storage::disk('public')->delete($attachment->file_path);
        }

        // Datenbankeintrag löschen
        $attachment->delete();

        return response()->json(['message' => 'Datei erfolgreich gelöscht'], 200);
    }
}