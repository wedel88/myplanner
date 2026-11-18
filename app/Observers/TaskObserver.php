<?php

namespace App\Observers;

use App\Models\Task;
use Carbon\Carbon;

class TaskObserver
{
    public function retrieved(Task $task)
    {
        // --- 1. LOGIK FÜR ABLAUFDATUM (closed_incomplete) ---
        if ($task->due_at && !in_array($task->status, ['completed', 'closed_incomplete'])) {
            $dueDate = $task->due_at instanceof Carbon ? $task->due_at : Carbon::parse($task->due_at);
            if ($dueDate->isPast()) {
                $task->status = 'closed_incomplete';
                Task::where('id', $task->id)->update(['status' => 'closed_incomplete']);
                $task->syncOriginal();
            }
        }

        // --- 2. LOGIK FÜR GEPLANTEN START (in_progress) ---
        // Wenn Startdatum gesetzt, in der Vergangenheit/Jetzt liegt, und Status noch "open" ist
        if ($task->planned_start_at && $task->status === 'open') {
            $startDate = $task->planned_start_at instanceof Carbon
                ? $task->planned_start_at
                : Carbon::parse($task->planned_start_at);
            
            // Wenn der Startzeitpunkt erreicht oder überschritten ist
            if ($startDate->isPast() || $startDate->isToday()) {
                $task->status = 'in_progress';
                Task::where('id', $task->id)->update(['status' => 'in_progress']);
                $task->syncOriginal();
            }
        }
    }
}