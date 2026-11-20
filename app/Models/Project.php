<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Project extends Model
{
    // Hier sagst du Laravel, welche Felder in der DB gespeichert werden dürfen
    protected $fillable = [
        'name',
        'description',
        'sort_order',
        'user_id' // user_id hinzufügen
    ];

    // Optional: Wenn du eine Beziehung zu den Containern brauchst
    public function containers()
    {
        return $this->hasMany(Container::class)->orderBy('position');
    }
    public function comments()
    {
        return $this->morphMany(Comment::class, 'commentable');
    }
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}