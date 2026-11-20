<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\ProjectController;
use App\Http\Controllers\Api\ContainerController;
use App\Http\Controllers\Api\TaskController;
use App\Http\Controllers\Api\SubtaskController;
use App\Http\Controllers\Api\CommentController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\DashboardController;
use App\Http\Controllers\ProfileController;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\Response;

// ==========================================
// ÖFFENTLICHE ROUTEN (Kein Login nötig)
// ==========================================
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

//profilbild
// Öffentliche Route für Avatars mit Dateiendungen (.jpg, .png etc.)
Route::get('/avatars/{filename}', function ($filename) {
    $path = 'avatars/' . $filename;

    if (!Storage::disk('public')->exists($path)) {
        abort(404);
    }

    $file = Storage::disk('public')->get($path);
    $type = Storage::disk('public')->mimeType($path);

    return response($file, 200)->header('Content-Type', $type);
})->where('filename', '.*'); // 👈 WICHTIG: Erlaubt Punkte und Dateiendungen im Parameter!


// ==========================================
// GESCHÜTZTE ROUTEN (Nur mit Token)
// ==========================================
Route::middleware('auth:sanctum')->group(function () {

    // User-Auth
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/me', [AuthController::class, 'me']);

    // Projekte
    Route::apiResource('projects', ProjectController::class);
    Route::get('/projects/{project}/containers', [ProjectController::class, 'getContainersWithTasks']);
    Route::post('/projects/{project}/containers', [ContainerController::class, 'store']);
    Route::post('/projects/reorder', [ProjectController::class, 'reorder']);

    Route::post('/projects/{project}/members', [ProjectController::class, 'addMember']);
    Route::get('/projects/{project}/users', [ProjectController::class, 'users']);
    // Container (Spalten)
    Route::apiResource('containers', ContainerController::class);
    Route::put('/containers/{container}/position', [ContainerController::class, 'updatePosition']);
    Route::patch('/containers/{container}/reorder', [ContainerController::class, 'reorder']);

    // Tasks (Aufgaben)
    Route::apiResource('tasks', TaskController::class);
    Route::post('/containers/{container}/tasks', [TaskController::class, 'store']);
    Route::patch('/tasks/{task}/move', [TaskController::class, 'move']);
    Route::patch('/tasks/{task}/reorder', [TaskController::class, 'reorder']);

    // Subtasks (Teilpunkte)
    Route::apiResource('subtasks', SubtaskController::class);

    // Kommentare
    Route::get('/comments', [CommentController::class, 'index']);
    Route::post('/comments', [CommentController::class, 'store']);
    Route::delete('/comments/{comment}', [CommentController::class, 'destroy']);

    Route::get('/dashboard/tasks', [DashboardController::class, 'index']);
    //Profile
    Route::get('/me', [ProfileController::class, 'show']);
    Route::post('/profile/avatar', [ProfileController::class, 'updateAvatar']);
    Route::put('/profile', [ProfileController::class, 'update']);
});