<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Group;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use App\Models\Project;


class GroupController extends Controller
{
    // 1. Alle Gruppen abrufen
    public function index()
    {
        $user = Auth::user();
        $groups = $user->groups()->with(['owner', 'users', 'projects'])->get();

        return response()->json($groups, 200);
    }

    // 2. Neue Gruppe erstellen (Hier lag der Fehler: store fehlte!)
    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'description' => 'nullable|string',
        ]);

        // Gruppe erstellen (Achtung: Hier created_by_user_id statt user_id nutzen)
        $group = Group::create([
            'name' => $validated['name'],
            'description' => $validated['description'] ?? null,
            'created_by_user_id' => auth()->id(),
        ]);

        // Den Ersteller direkt als Admin zur Gruppe hinzufügen (in die Pivot-Tabelle)
        $group->users()->attach(auth()->id(), ['role' => 'admin']);

        return response()->json([
            'message' => 'Gruppe erfolgreich erstellt!',
            'data' => $group->load('users')
        ], 201);
    }

    // 3. Gruppendetails anzeigen
    public function show($id)
    {
        $group = Group::with(['owner', 'users', 'projects'])->findOrFail($id);

        if (!$group->users->contains(Auth::id())) {
            return response()->json(['message' => 'Zugriff verweigert.'], 403);
        }

        return response()->json($group, 200);
    }

    // 4. Mitglied zur Gruppe hinzufügen
    // Mitglied hinzufügen oder einladen
    public function addMember(Request $request, Group $group)
    {
        // 1. Validieren, ob die E-Mail existiert
        $request->validate([
            'email' => 'required|email|exists:users,email',
            'role' => 'required|in:admin,product_owner,member',
        ]);

        $user = User::where('email', $request->email)->first();

        // 2. Prüfen, ob der User bereits in der Gruppe ist (verhindert SQL-Fehler)
        if ($group->users()->where('user_id', $user->id)->exists()) {
            return response()->json(['message' => 'User ist bereits in der Gruppe.'], 422);
        }

        // 3. Anhängen mit Rolle
        $group->users()->attach($user->id, ['role' => $request->role]);

        return response()->json(['message' => 'Erfolgreich hinzugefügt!']);
    }

    // Rolle eines Mitglieds aktualisieren
    public function updateMemberRole(Request $request, Group $group, $userId)
    {
        $request->validate([
            'role' => 'required|in:admin,product_owner,member',
        ]);

        // Aktualisiert die Rolle in der Pivot-Tabelle `group_user`
        $group->users()->updateExistingPivot($userId, [
            'role' => $request->role
        ]);

        return response()->json(['message' => 'Rolle aktualisiert!']);
    }

    // Mitglied entfernen
    public function removeMember(Group $group, User $user)
    {
        // Verhindern, dass der letzte Admin sich selbst entfernt
        $adminCount = $group->users()->wherePivot('role', 'admin')->count();
        if ($adminCount <= 1 && $user->id === auth()->id()) {
            return response()->json(['message' => 'Die Gruppe muss mindestens einen Admin behalten.'], 422);
        }

        $group->users()->detach($user->id);

        return response()->json(['message' => 'Mitglied erfolgreich entfernt.'], 200);
    }
    public function getMembers(Group $group)
    {
        if (!$group->users->contains(Auth::id())) {
            return response()->json(['message' => 'Zugriff verweigert.'], 403);
        }
        return response()->json($group->users()->withPivot('role')->get(), 200);
    }

    public function update(Request $request, Group $group)
    {
        if (!$group->users()->where('user_id', Auth::id())->wherePivot('role', 'admin')->exists()) {
            return response()->json(['message' => 'Nur Admins dürfen die Gruppe bearbeiten.'], 403);
        }
        $validated = $request->validate([
            'name' => 'sometimes|required|string|max:255',
            'description' => 'nullable|string',
        ]);
        $group->update($validated);
        return response()->json($group, 200);
    }

    public function destroy(Group $group)
    {
        if ($group->created_by_user_id !== Auth::id()) {
            return response()->json(['message' => 'Nur der Ersteller darf die Gruppe löschen.'], 403);
        }
        $group->users()->detach();
        $group->delete();
        return response()->json(['message' => 'Gruppe gelöscht'], 200);
    }
    // Liefert alle Projekte, auf die der User Zugriff hat und die noch keiner Gruppe zugewiesen sind
    public function availableProjects(Request $request)
    {
        $user = Auth::user();
        if (!$user) {
            return response()->json(['message' => 'Unauthenticated.'], 401);
        }

        $projects = \App\Models\Project::where(function ($query) use ($user) {
            // 1. Eigene Projekte ODER Projekte, in denen man Mitglied ist
            $query->where('user_id', $user->id)
                ->orWhereHas('users', function ($q) use ($user) {
                    $q->where('users.id', $user->id);
                });
        })
            ->whereNull('group_id') // 2. UND die noch in keiner Gruppe sind
            ->get();

        return response()->json($projects, 200);
    }
    // Ordnet ein bestehendes Projekt einer Gruppe zu (Nur Admin & Product Owner)
    // Ordnet ein bestehendes Projekt einer Gruppe zu
    public function assignProject(Request $request, Group $group)
    {
        $role = $this->getUserRole($group);
        if (!in_array($role, ['admin', 'product_owner'])) {
            return response()->json(['message' => 'Keine Berechtigung: Nur Admins und Product Owner dürfen Projekte hinzufügen.'], 403);
        }

        $validated = $request->validate([
            'project_id' => 'required|exists:projects,id',
        ]);

        $project = \App\Models\Project::findOrFail($validated['project_id']);

        // Sicherheitscheck: Hat der User überhaupt Zugriff auf dieses Projekt?
        $user = auth()->user();
        $hasAccess = $project->user_id === $user->id || $project->users()->where('users.id', $user->id)->exists();

        if (!$hasAccess) {
            return response()->json(['message' => 'Du hast keinen Zugriff auf dieses Projekt.'], 403);
        }

        // Projekt der Gruppe zuweisen
        $project->update(['group_id' => $group->id]);

        return response()->json([
            'message' => 'Projekt erfolgreich zur Gruppe hinzugefügt.',
            'data' => $project->load('group')
        ], 200);
    }

    // Entfernt ein Projekt aus der Gruppe
    public function removeProject(Request $request, Group $group, Project $project)
    {
        $role = $this->getUserRole($group);

        if (!in_array($role, ['admin', 'product_owner'])) {
            return response()->json(['message' => 'Keine Berechtigung: Nur Admins und Product Owner dürfen Projekte entfernen.'], 403);
        }

        if ($project->group_id !== $group->id) {
            return response()->json(['message' => 'Dieses Projekt ist nicht Teil dieser Gruppe.'], 400);
        }

        // Zuordnung aufheben
        $project->update(['group_id' => null]);

        return response()->json([
            'message' => 'Projekt erfolgreich aus der Gruppe entfernt.',
            'data' => $project
        ], 200);
    }
    private function getUserRole(Group $group)
    {
        $user = auth()->user();
        if (!$user)
            return null;

        // Sucht den User in der Pivot-Tabelle der Gruppe
        $pivot = $group->users()->where('user_id', $user->id)->first();

        return $pivot ? $pivot->pivot->role : null;
    }
}