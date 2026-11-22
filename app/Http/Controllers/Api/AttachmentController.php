<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Attachment;
use App\Models\Task;
use App\Models\Project;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class AttachmentController extends Controller
{
    // 1. Anhang für eine bestimmte Task hochladen
    public function storeForTask(Request $request, Task $task)
    {
        return $this->saveAttachment($request, [
            'task_id' => $task->id,
            'project_id' => null,
            'folder' => 'task-attachments'
        ]);
    }

    // 2. Anhang direkt für ein gesamtes Projekt hochladen (NEU)
    public function storeForProject(Request $request, Project $project)
    {
        return $this->saveAttachment($request, [
            'task_id' => null,
            'project_id' => $project->id,
            'folder' => 'project-attachments'
        ]);
    }

    // Interne Hilfs-Methode für den Upload (verhindert Code-Dopplung)
    private function saveAttachment(Request $request, array $options)
    {
        $request->validate([
            'file' => 'required|file|max:10240', // Max 10MB
        ]);

        $file = $request->file('file');
        $originalName = $file->getClientOriginalName();
        
        // Im entsprechenden Ordner speichern
        $path = $file->store($options['folder'], 'public');

        $attachment = Attachment::create([
            'user_id' => $request->user()->id,
            'task_id' => $options['task_id'],
            'project_id' => $options['project_id'],
            'file_path' => $path,
            'file_name' => $originalName,
        ]);

        return response()->json($attachment->load('user'), 201);
    }

    // Universelles Löschen (funktioniert für Task- und Projekt-Anhänge gleichermaßen)
    public function destroy(Attachment $attachment)
    {
        // Datei aus dem Storage löschen
        if (Storage::disk('public')->exists($attachment->file_path)) {
            Storage::disk('public')->delete($attachment->file_path);
        }

        $attachment->delete();

        return response()->json(['message' => 'Anhang erfolgreich gelöscht']);
    }
}