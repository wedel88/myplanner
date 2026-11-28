<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use App\Models\Task;
use Carbon\Carbon;

class GenerateRecurringTasks extends Command
{
    protected $signature = 'tasks:generate-recurring';
    protected $description = 'Erstellt täglich die fälligen wiederkehrenden Aufgaben (holt Verpasstes nach)';

    public function handle()
    {
        $count = 0;
        $today = Carbon::today();

        // 1. Alle "Original"-Aufgaben holen
        $recurringTasks = Task::where('recurrence', '!=', 'none')
            ->whereNotNull('due_at')
            ->whereNull('recurrence_parent_id')
            ->get();

        foreach ($recurringTasks as $task) {
            // Das ENDDATUM der Serie (bleibt immer gleich)
            $endDate = Carbon::parse($task->due_at);

            // Der STARTPUNKT ist der Tag, an dem die Aufgabe erstellt wurde
            $startDate = Carbon::parse($task->created_at)->startOfDay();

            // Das AKTUELLE Datum, für das wir prüfen
            $currentDate = $startDate->copy();

            // Schleife: Vom Startdatum bis HEUTE (oder bis zum Enddatum)
            while ($currentDate->lessThanOrEqualTo($today) && $currentDate->lessThanOrEqualTo($endDate)) {
                
                // Prüfen, ob für DIESEN Tag schon eine Kopie existiert
                $existingCopy = Task::where('recurrence_parent_id', $task->id)
                                    ->whereDate('planned_start_at', $currentDate->toDateString())
                                    ->exists();

                if (!$existingCopy) {
                    // Neue Kopie erstellen
                    Task::create([
                        'container_id' => $task->container_id,
                        'title' => $task->title,
                        'description' => $task->description,
                        'status' => 'open',
                        'assigned_user_id' => $task->assigned_user_id,
                        
                        // DAS SIND DIE WICHTIGEN ÄNDERUNGEN:
                        'planned_start_at' => $currentDate->copy(), // Start am jeweiligen Tag
                        'planned_end_at' => $currentDate->copy(),   // Ende am jeweiligen Tag
                        'due_at' => $endDate->copy(),               // DEADLINE BLEIBT DAS ENDDATUM!
                        
                        'position' => $task->position,
                        'recurrence' => $task->recurrence,
                        'recurrence_parent_id' => $task->id,
                        'recurrence_day_of_week' => $task->recurrence_day_of_week,
                        'recurrence_day_of_month' => $task->recurrence_day_of_month,
                    ]);
                    $count++;
                }

                // Berechne das NÄCHSTE Datum (je nach Wiederholung)
                if ($task->recurrence === 'daily') {
                    $currentDate->addDay();
                } elseif ($task->recurrence === 'weekly') {
                    if ($task->recurrence_day_of_week) {
                        $currentDate = $currentDate->copy()->next((int)$task->recurrence_day_of_week);
                    } else {
                        $currentDate->addWeek();
                    }
                } elseif ($task->recurrence === 'monthly') {
                    if ($task->recurrence_day_of_month) {
                        $currentDate = $currentDate->copy()->addMonth()->setDay((int)$task->recurrence_day_of_month);
                    } else {
                        $currentDate->addMonth();
                    }
                }
            }
        }

        $this->info("$count wiederkehrende Aufgaben wurden bis heute erstellt.");
    }
}