<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens; // <-- 1. Hier importieren

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable; // <-- 2. Hier benutzen (ohne Namespace davor)

    protected $fillable = [
        'name',
        'email',
        'password',
        'avatar',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected $casts = [
        'email_verified_at' => 'datetime',
    ];
    public function projects()
    {
        return $this->hasMany(Project::class);
    }

    // Projekte, in denen der User Mitglied ist (Many-to-Many)
    public function sharedProjects()
    {
        return $this->belongsToMany(Project::class);
    }
}