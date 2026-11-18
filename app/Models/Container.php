<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Container extends Model
{
    use HasFactory;

    protected $fillable = ['project_id', 'name', 'position'];

    // Ein Container gehört zu einem Projekt
    public function project()
    {
        return $this->belongsTo(Project::class);
    }

    // Ein Container hat viele Tasks
    public function tasks()
    {
        return $this->hasMany(Task::class);
    }
}