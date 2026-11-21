<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Task;
use App\Models\TaskAttachment;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class TaskAttachmentController extends Controller
{
    public function store(Request $request, Task $task)
    {
        $request->validate([
            'file' => 'required|file|max:10240', // Max 10MB
        ]);

        $file = $request->file('file');
        $originalName = $file->getClientOriginalName();
        
        // Im Ordner 'task-attachments' speichern
        $path = $file->store('task-attachments', 'public');

        $attachment = $task->attachments()->create([
            'user_id' => $request->user()->id,
            'file_path' => $path,
            'file_name' => $originalName,
        ]);

        return response()->json($attachment->load('user'), 201);
    }

    public function destroy(TaskAttachment $attachment)
    {
        // Datei aus Storage löschen
        if (Storage::disk('public')->exists($attachment->file_path)) {
            Storage::disk('public')->delete($attachment->file_path);
        }

        $attachment->delete();

        return response()->json(['message' => 'Anhang gelöscht']);
    }
}