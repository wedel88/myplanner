<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Group extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'description',
        'created_by_user_id',
    ];

    // Ersteller der Gruppe
    public function owner()
    {
        return $this->belongsTo(User::class, 'created_by_user_id');
    }

    // Mitglieder der Gruppe (Many-to-Many mit Rolle in der Pivot-Tabelle)
    public function users()
    {
        return $this->belongsToMany(User::class, 'group_user')
                    ->withPivot('role')
                    ->withTimestamps();
    }

    // Projekte in dieser Gruppe
    public function projects()
    {
        return $this->hasMany(Project::class);
    }
}