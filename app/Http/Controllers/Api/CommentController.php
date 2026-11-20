<?php


namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Comment;
use Illuminate\Http\Request;

class CommentController extends Controller
{
    // Kommentare für eine Task oder ein Projekt laden
    public function index(Request $request)
    {
        $request->validate([
            'commentable_type' => 'required|string',
            'commentable_id' => 'required|integer',
        ]);

        // Wir bauen den Klassennamen zusammen (z.B. App\Models\Task)
        $modelClass = 'App\\Models\\' . ucfirst($request->commentable_type);

        if (!class_exists($modelClass)) {
            return response()->json(['error' => 'Modell nicht gefunden'], 404);
        }

        $commentable = $modelClass::findOrFail($request->commentable_id);

        // Lade die Kommentare inklusive der User-Daten (falls vorhanden)
        $comments = $commentable->comments()->with('user')->orderBy('created_at', 'asc')->get();

        return response()->json($comments, 200);
    }

    // Einen neuen Kommentar erstellen
    public function store(Request $request)
    {
        $validated = $request->validate([
            'commentable_type' => 'required|string',
            'commentable_id' => 'required|integer',
            'content' => 'required|string',
        ]);

        $modelClass = 'App\\Models\\' . ucfirst($request->commentable_type);
        $commentable = $modelClass::findOrFail($request->commentable_id);

        $comment = $commentable->comments()->create([
            'content' => $validated['content'],
            'user_id' => auth()->id(), // <-- NEU: Der eingeloggte User
        ]);

        return response()->json($comment->load('user'), 201);
    }
    public function destroy(Comment $comment)
    {
        // Prüfen, ob der eingeloggte User der Autor des Kommentars ist
        if ($comment->user_id !== auth()->id()) {
            return response()->json(['error' => 'Du kannst nur deine eigenen Kommentare löschen.'], 403);
        }

        $comment->delete();
        return response()->json(['message' => 'Kommentar gelöscht'], 200);
    }
}