<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Project extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'description',
        'sort_order',
        'group_id',
        'user_id',
        'is_archived',
    ];

    // Der Besitzer (Ersteller) des Projekts
    public function owner()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    // Alle Mitglieder des Projekts (Many-to-Many)
    public function users()
    {
        return $this->belongsToMany(User::class, 'project_user');
    }

    // Die Container (Spalten) des Projekts
    public function containers()
    {
        return $this->hasMany(Container::class)->orderBy('position');
    }

    // Die Kommentare des Projekts
    public function comments()
    {
        return $this->morphMany(Comment::class, 'commentable');
    }
    // 1. Nur die Dateien, die direkt am Projekt hochgeladen wurden:
    public function attachments()
    {
        return $this->hasMany(Attachment::class);
    }

    // 2. Alle Dateien des Projekts INKLUSIVE aller Task-Dateien:
    public function getAllAttachmentsAttribute()
    {
        // Eigene Projekt-Dateien holen
        $projectFiles = $this->attachments;

        // Alle Task-Dateien über die Container und Tasks einsammeln
        $taskFiles = $this->containers()
            ->with('tasks.attachments')
            ->get()
            ->flatMap(function ($container) {
                return $container->tasks->flatMap(function ($task) {
                    return $task->attachments;
                });
            });

        // Beide Listen zusammenführen
        return $projectFiles->merge($taskFiles);
    }
    public function group()
    {
        return $this->belongsTo(Group::class);
    }
}