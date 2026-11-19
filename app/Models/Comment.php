<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Comment extends Model
{
    protected $fillable = [
        'content',
        'user_id',
    ];

    // Die polymorphe Beziehung
    public function commentable()
    {
        return $this->morphTo();
    }

    // Optional: Die Beziehung zum User (falls später eingeloggt)
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
