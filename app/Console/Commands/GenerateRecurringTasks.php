<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Task;
use Carbon\Carbon;

class GenerateRecurringTasks extends Command
{
    protected $signature = 'tasks:generate-recurring';
    protected $description = 'Erstellt neue Kopien von wiederkehrenden Tasks';

    public function handle()
    {
        // 1. Alle Tasks finden, die sich wiederholen, erledigt sind und noch keine Kopie für den nächsten Zeitraum haben
        $recurringTasks = Task::where('recurrence', '!=', 'none')
            ->where('status', 'completed')
            ->get();

        $count = 0;

        foreach ($recurringTasks as $task) {
            // Prüfen, ob es bereits eine aktive (offene) Kopie für diesen Task gibt
            $existingCopy = Task::where('recurrence_parent_id', $task->id)
                ->where('status', '!=', 'completed')
                ->exists();

            if ($existingCopy)
                continue; // Wenn ja, überspringen

            // 2. Berechne das nächste Fälligkeitsdatum (basierend auf dem alten due_at)
            $newDueDate = null;
            if ($task->due_at) {
                $newDueDate = Carbon::parse($task->due_at);
                if ($task->recurrence === 'daily')
                    $newDueDate->addDay();
                if ($task->recurrence === 'weekly')
                    $newDueDate->addWeek();
                if ($task->recurrence === 'monthly')
                    $newDueDate->addMonth();
            }

            // 3. Die Kopie erstellen
            Task::create([
                'container_id' => $task->container_id,
                'title' => $task->title,
                'description' => $task->description,
                'status' => 'open', // Kopie startet immer als offen
                'assigned_user_id' => $task->assigned_user_id,
                'planned_start_at' => $task->planned_start_at,
                'planned_end_at' => $task->planned_end_at,
                'due_at' => $newDueDate,
                'position' => $task->position,
                'recurrence' => $task->recurrence, // Kopie wiederholt sich auch wieder
                'recurrence_parent_id' => $task->id,
            ]);

            $count++;
        }

        $this->info("$count wiederkehrende Aufgaben wurden erstellt.");
    }
}