<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\ProjectController;
use App\Http\Controllers\Api\ContainerController;
use App\Http\Controllers\Api\TaskController;
use App\Http\Controllers\Api\SubtaskController;
use App\Http\Controllers\Api\CommentController;

// Standard User-Route
Route::get('/user', function (Request $request) {
    return $request->user();
});
// Route für die Container eines spezifischen Projekts
Route::get('/projects/{project}/containers', [ProjectController::class, 'getContainersWithTasks']);

// Neue Container für ein Projekt erstellen
Route::post('/projects/{project}/containers', [ContainerController::class, 'store']);

// Neue Tasks für einen Container erstellen
Route::post('/containers/{container}/tasks', [TaskController::class, 'store']);

//update route 
Route::put('/tasks/{task}', [TaskController::class, 'update']);

// Task löschen
Route::delete('/tasks/{task}', [TaskController::class, 'destroy']);

// Container löschen
Route::delete('/containers/{container}', [ContainerController::class, 'destroy']);

Route::put('/containers/{container}/position', [ContainerController::class, 'updatePosition']);

// REST-API-Routen für das Kanban-Board
Route::apiResource('projects', ProjectController::class);
Route::apiResource('containers', ContainerController::class);
Route::apiResource('tasks', TaskController::class);
Route::apiResource('subtasks', SubtaskController::class);
Route::apiResource('comments', CommentController::class);