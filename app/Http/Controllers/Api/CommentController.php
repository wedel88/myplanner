<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Comment;
use Illuminate\Http\Request;

class CommentController extends Controller
{
    // Alle Kommentare abrufen (optional nach task_id filtern)
    public function index(Request $request)
    {
        $query = Comment::query();

        if ($request->has('task_id')) {
            $query->where('task_id', $request->task_id);
        }

        return response()->json($query->get(), 200);
    }

    // Einen neuen Kommentar erstellen
    public function store(Request $request)
    {
        $validated = $request->validate([
            'task_id' => 'required|exists:tasks,id',
            'content' => 'required|string',
        ]);

        $comment = Comment::create($validated);

        return response()->json([
            'message' => 'Kommentar erfolgreich erstellt!',
            'data' => $comment
        ], 201);
    }

    // Einen einzelnen Kommentar anzeigen
    public function show(Comment $comment)
    {
        return response()->json($comment, 200);
    }

    // Einen Kommentar aktualisieren
    public function update(Request $request, Comment $comment)
    {
        $validated = $request->validate([
            'content' => 'required|string',
        ]);

        $comment->update($validated);

        return response()->json([
            'message' => 'Kommentar aktualisiert',
            'data' => $comment
        ], 200);
    }

    // Einen Kommentar löschen
    public function destroy(Comment $comment)
    {
        $comment->delete();
        return response()->json(['message' => 'Kommentar gelöscht'], 200);
    }
}