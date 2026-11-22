<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Group;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

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
        $request->validate([
            'name' => 'required|string|max:255',
            'description' => 'nullable|string',
        ]);

        $user = Auth::user();

        $group = Group::create([
            'name' => $request->name,
            'description' => $request->description,
            'created_by_user_id' => $user->id,
        ]);

        // Den Ersteller direkt als Mitglied hinzufügen
        $group->users()->attach($user->id);

        return response()->json([
            'message' => 'Gruppe erfolgreich erstellt!',
            'group' => $group->load(['owner', 'users'])
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
    public function addMember(Request $request, $id)
    {
        $request->validate([
            'email' => 'required|email|exists:users,email',
        ]);

        $group = Group::findOrFail($id);

        if (!$group->users->contains(Auth::id())) {
            return response()->json(['message' => 'Zugriff verweigert.'], 403);
        }

        $userToAdd = User::where('email', $request->email)->first();

        if ($group->users->contains($userToAdd->id)) {
            return response()->json(['message' => 'Benutzer ist bereits in der Gruppe.'], 400);
        }

        $group->users()->attach($userToAdd->id);

        return response()->json([
            'message' => 'Benutzer erfolgreich zur Gruppe hinzugefügt!',
            'users' => $group->users
        ], 200);
    }
}