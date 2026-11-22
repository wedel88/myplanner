<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Comment;
use App\Models\Attachment;
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

        $type = $request->commentable_type;
        $modelClass = str_contains($type, '\\') ? $type : 'App\\Models\\' . ucfirst($type);

        if (!class_exists($modelClass)) {
            return response()->json(['error' => 'Modell nicht gefunden'], 404);
        }

        $commentable = $modelClass::findOrFail($request->commentable_id);

        $comments = $commentable->comments()
            ->with(['user', 'attachments'])
            ->orderBy('created_at', 'asc')
            ->get();

        return response()->json($comments, 200);
    }

    // Einen neuen Kommentar erstellen
    public function store(Request $request)
    {
        \Illuminate\Support\Facades\Log::info('FILES IM REQUEST:', [
            'has_file' => $request->hasFile('file'),
            'all_files' => $request->allFiles(),
            'all_inputs' => $request->all(),
        ]);

        $request->validate([
            'commentable_type' => 'required|string',
            'commentable_id' => 'required|integer',
            'content' => 'nullable|string',
            'file' => 'nullable|file|max:10240',
        ]);

        $type = $request->commentable_type;
        $modelClass = str_contains($type, '\\') ? $type : 'App\\Models\\' . ucfirst($type);

        $comment = Comment::create([
            'user_id' => $request->user()->id,
            'commentable_type' => $modelClass,
            'commentable_id' => $request->commentable_id,
            'content' => $request->input('content', ''),
        ]);

        // Wenn hier eine Datei erkannt wird, wird sie gespeichert
        if ($request->hasFile('file')) {
            $file = $request->file('file');
            $path = $file->store('comment-attachments', 'public');

            $attachment = Attachment::create([
                'user_id' => $request->user()->id,
                'comment_id' => $comment->id,
                'project_id' => $modelClass === 'App\\Models\\Project' ? $request->commentable_id : null,
                'task_id' => $modelClass === 'App\\Models\\Task' ? $request->commentable_id : null,
                'file_path' => $path,
                'file_name' => $file->getClientOriginalName(),
            ]);

            \Illuminate\Support\Facades\Log::info('ATTACHMENT CREATED:', $attachment->toArray());
        }

        return response()->json($comment->load(['user', 'attachments']), 201);
    }

    // Kommentar bearbeiten
    public function update(Request $request, Comment $comment)
    {
        $user = $request->user();
        if (!$user || $comment->user_id !== $user->id) {
            return response()->json(['message' => 'Unauthorized'], 403);
        }

        $request->validate([
            'content' => 'required|string',
        ]);

        $comment->update([
            'content' => $request->input('content'),
        ]);

        return response()->json($comment->load(['user', 'attachments']), 200);
    }

    public function destroy(Comment $comment)
    {
        if ($comment->user_id !== auth()->id()) {
            return response()->json(['error' => 'Du kannst nur deine eigenen Kommentare löschen.'], 403);
        }

        // Alle verknüpften Attachments löschen
        foreach ($comment->attachments as $att) {
            \Illuminate\Support\Facades\Storage::disk('public')->delete($att->file_path);
            $att->delete();
        }

        $comment->delete();
        return response()->json(['message' => 'Kommentar gelöscht'], 200);
    }
}