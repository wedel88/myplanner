<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

Route::get('/user', function (Request $request) {
    return $request->user();
});

use App\Http\Controllers\Api\ProjectController;

// REST-API-Routen für Projekte
Route::apiResource('projects', ProjectController::class);

use App\Http\Controllers\Api\ProjectController;
use App\Http\Controllers\Api\ContainerController;

// REST-API-Routen
Route::apiResource('projects', ProjectController::class);
Route::apiResource('containers', ContainerController::class);