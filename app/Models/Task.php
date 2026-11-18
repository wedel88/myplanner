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
        'due_at',
        'position'
    ];
    protected $casts = [
        'due_at' => 'datetime',
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
}