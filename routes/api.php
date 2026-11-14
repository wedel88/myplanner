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

// REST-API-Routen für das Kanban-Board
Route::apiResource('projects', ProjectController::class);
Route::apiResource('containers', ContainerController::class);
Route::apiResource('tasks', TaskController::class);
Route::apiResource('subtasks', SubtaskController::class);
Route::apiResource('comments', CommentController::class);