<?php

namespace App\Observers;

use App\Models\Task;
use Carbon\Carbon;

class TaskObserver
{
    public function retrieved(Task $task)
    {
        // 1. Prüfen, ob ein Datum existiert und die Task noch offen ist
        if ($task->due_at && 
            !in_array($task->status, ['completed', 'closed_incomplete'])) {
            
            // 2. Datum sicher parsen
            $dueDate = $task->due_at instanceof Carbon ? $task->due_at : Carbon::parse($task->due_at);

            // 3. Wenn das Datum in der Vergangenheit liegt
            if ($dueDate->isPast()) {
                
                // 4. Status im Model ändern (für das aktuelle Flutter-Response)
                $task->status = 'closed_incomplete';
                
                // 5. DIREKTES DB-UPDATE (umgeht Eloquent-Probleme mit Enums)
                try {
                    // Wir nutzen ein Query-Update, um die Datenbank direkt anzusprechen
                    Task::where('id', $task->id)
                        ->update(['status' => 'closed_incomplete']);
                    
                    // Optional: Das Model als "synchronisiert" markieren
                    $task->syncOriginal(); 
                    
                } catch (\Exception $e) {
                    \Log::error('Fehler im TaskObserver beim Update: ' . $e->getMessage());
                }
            }
        }
    }
}