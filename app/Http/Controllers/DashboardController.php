<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Task;
use Carbon\Carbon;

class DashboardController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();

        // 1. Alle Projekte des Users (eigene + geteilte) für den Filter laden
        $projects = \App\Models\Project::where('user_id', $user->id)
            ->orWhereHas('users', function ($q) use ($user) {
                $q->where('users.id', $user->id);
            })->with('group')->get();

        // 2. Alle Gruppen des Users für den Filter laden
        $groups = $user->groups()->get();

        // 3. Die Aufgaben laden (wie gehabt)
        $tasks = Task::whereHas('container.project', function ($query) use ($user) {
            $query->where('user_id', $user->id) // Eigene Projekte
                ->orWhereHas('users', function ($q) use ($user) {
                    $q->where('users.id', $user->id); // Projekte, in denen man Mitglied ist
                });
        })
            ->with([
                'container.project.group', // Wichtig: Gruppe mitladen für den Filter
                'subtasks',
                'assignedUser'
            ])
            ->orderBy('due_at', 'asc')
            ->get();

        // 4. Statistiken berechnen (wie gehabt)
        $now = Carbon::now();
        $stats = [
            'total' => $tasks->count(),
            'completed' => $tasks->where('status', 'completed')->count(),
            'pending' => $tasks->where('status', '!=', 'completed')->count(),
            'overdue' => $tasks->filter(function ($task) use ($now) {
                return $task->status != 'completed' && $task->due_at && Carbon::parse($task->due_at)->isPast();
            })->count(),
            'completed_today' => $tasks->filter(function ($task) use ($now) {
                return $task->status === 'completed' && $task->updated_at && Carbon::parse($task->updated_at)->isToday();
            })->count(),
            'completed_week' => $tasks->filter(function ($task) use ($now) {
                return $task->status === 'completed' && $task->updated_at && Carbon::parse($task->updated_at)->gte($now->copy()->subDays(7));
            })->count(),
            'completed_month' => $tasks->filter(function ($task) use ($now) {
                return $task->status === 'completed' && $task->updated_at && Carbon::parse($task->updated_at)->isCurrentMonth();
            })->count(),
        ];

        return response()->json([
            'stats' => $stats,
            'tasks' => $tasks,
            'projects' => $projects, // NEU
            'groups' => $groups,     // NEU
        ]);
    }
        // NEU: Liefert die Chart-Daten für einen bestimmten Zeitraum
    public function chartData(Request $request)
    {
        $user = $request->user();
        $range = $request->query('range', '7_days'); // 'today', '7_days', 'month'
        
        $now = Carbon::now();
        $dates = [];
        $data = [];

        // 1. Bestimme die Tage, die im Chart angezeigt werden sollen
        if ($range === 'today') {
            // Stunden von 0 bis 23 Uhr
            for ($i = 0; $i < 24; $i++) {
                $dates[] = $now->copy()->startOfDay()->addHours($i);
            }
        } elseif ($range === '7_days') {
            // Die letzten 7 Tage
            for ($i = 6; $i >= 0; $i--) {
                $dates[] = $now->copy()->subDays($i)->startOfDay();
            }
        } else { // 'month'
            // Die letzten 30 Tage (oder aktueller Monat)
            for ($i = 29; $i >= 0; $i--) {
                $dates[] = $now->copy()->subDays($i)->startOfDay();
            }
        }

        // 2. Für jeden Tag die Anzahl der erledigten Aufgaben zählen
        foreach ($dates as $date) {
            $count = \App\Models\Task::whereHas('container.project', function ($query) use ($user) {
                    $query->where('user_id', $user->id)
                        ->orWhereHas('users', function ($q) use ($user) {
                            $q->where('users.id', $user->id);
                        });
                })
                ->where('status', 'completed')
                ->whereDate('updated_at', $date) // Prüfen, an welchem Tag es erledigt wurde
                ->count();

            $data[] = [
                'label' => $range === 'today' 
                    ? $date->format('H:00') 
                    : $date->format('d.m.'),
                'value' => $count,
            ];
        }

        return response()->json($data, 200);
    }
}