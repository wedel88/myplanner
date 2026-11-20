<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

class ProfileController extends Controller
{
    // Gibt die Daten für /api/me zurück
    public function show(Request $request)
    {
        return response()->json($request->user());
    }

    // Aktualisiert Profil-Daten (Name, E-Mail, Passwort)
    public function update(Request $request)
    {
        $user = $request->user();

        // Validierung der Eingaben
        $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users,email,' . $user->id,
            'current_password' => 'nullable|required_with:password',
            'password' => 'nullable|string|min:6',
        ]);

        // Name und E-Mail aktualisieren
        $user->name = $request->name;
        $user->email = $request->email;

        // Passwort-Änderung prüfen, falls ein neues übergeben wurde
        if ($request->filled('password')) {
            if (!Hash::check($request->current_password, $user->password)) {
                return response()->json([
                    'message' => 'Das aktuelle Passwort ist nicht korrekt.'
                ], 422);
            }

            $user->password = Hash::make($request->password);
        }

        $user->save();

        return response()->json([
            'message' => 'Profil erfolgreich aktualisiert!',
            'user' => $user
        ], 200);
    }
    public function updateAvatar(Request $request)
    {
        $request->validate([
            'avatar' => 'required|image|max:2048', // max 2MB
        ]);

        $path = $request->file('avatar')->store('avatars', 'public');

        $user = $request->user();
        $user->avatar = $path;
        $user->save();

        return response()->json([
            'message' => 'Avatar erfolgreich aktualisiert',
            'avatar' => $path
        ]);
    }
}