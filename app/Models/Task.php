<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use App\Models\Subtask;

class Task extends Model
{
    use HasFactory;

    protected $fillable = [
        'container_id',
        'title',
        'description',
        'status',
        'is_ready', // <-- NEU HINZUFÜGEN
        'assigned_user_id',
        'planned_start_at',
        'planned_end_at',
        'due_at',
        'position',
        'recurrence',
        'recurrence_parent_id',
    ];
    protected $casts = [
        'due_at' => 'datetime',
        'planned_start_at' => 'datetime',
        'planned_end_at' => 'datetime',
    ];

    // Ein Task gehört zu einem Container
    public function container()
    {
        return $this->belongsTo(Container::class);
    }
    public function subtasks()
    {
        return $this->hasMany(Subtask::class);
    }
    public function comments()
    {
        return $this->morphMany(Comment::class, 'commentable');
    }
    public function assignedUser()
    {
        return $this->belongsTo(User::class, 'assigned_user_id');
    }
    public function attachments()
    {
        return $this->hasMany(Attachment::class);
    }
    public function project()
    {
        return $this->belongsTo(Project::class);
    }
}