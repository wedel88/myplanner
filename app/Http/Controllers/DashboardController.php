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

        // Alle Aufgaben aus Projekten, bei denen der User Mitglied ist
        $tasks = Task::whereHas('container.project', function ($query) use ($user) {
            $query->whereHas('users', function ($q) use ($user) {
                $q->where('users.id', $user->id);
            });
        })
            ->with(['container.project', 'subtasks', 'assignedUser'])
            ->orderBy('due_at', 'asc')
            ->get();

        // Erweiterte Statistiken berechnen
        $now = Carbon::now();

        $stats = [
            'total' => $tasks->count(),
            'completed' => $tasks->where('status', 'completed')->count(),
            'pending' => $tasks->where('status', '!=', 'completed')->count(),
            // Zeitbasierte Statistiken für erledigte Aufgaben
            'completed_today' => $tasks->filter(function ($task) use ($now) {
                return $task->status === 'completed' &&
                    $task->updated_at &&
                    Carbon::parse($task->updated_at)->isToday();
            })->count(),
            'completed_week' => $tasks->filter(function ($task) use ($now) {
                return $task->status === 'completed' &&
                    $task->updated_at &&
                    Carbon::parse($task->updated_at)->gte($now->copy()->subDays(7));
            })->count(),
            'completed_month' => $tasks->filter(function ($task) use ($now) {
                return $task->status === 'completed' &&
                    $task->updated_at &&
                    Carbon::parse($task->updated_at)->isCurrentMonth();
            })->count(),
        ];

        return response()->json([
            'stats' => $stats,
            'tasks' => $tasks,
        ]);
    }
}