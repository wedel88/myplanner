<?php
namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\Task;

class DashboardController extends Controller
{
    public function index(Request $request)
    {
        $user = $request->user();

        // Hole alle Aufgaben aus Projekten, bei denen der User Mitglied ist
        // (inklusive zugehörigem Projekt, Spalte und Subtasks)
        $tasks = Task::whereHas('container.project', function ($query) use ($user) {
            $query->whereHas('users', function ($q) use ($user) {
                $q->where('users.id', $user->id);
            });
        })
        ->with(['container.project', 'subtasks'])
        ->orderBy('due_at', 'asc') // Sortiert nach Ablaufdatum
        ->get();

        // Optional: Kleine Statistiken direkt mitliefern
        $stats = [
            'total' => $tasks->count(),
            'completed' => $tasks->where('status', 'completed')->count(), // Passe das Feld an deinen Status an
            'pending' => $tasks->where('status', '!=', 'completed')->count(),
        ];

        return response()->json([
            'stats' => $stats,
            'tasks' => $tasks,
        ]);
    }
}