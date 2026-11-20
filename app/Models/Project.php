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
        'user_id' // Das behalten wir als "Owner" (Ersteller) bei
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
}