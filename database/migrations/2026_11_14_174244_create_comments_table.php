<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('comments', function (Blueprint $table) {
            $table->id();
            // Polymorphe Beziehung (kann auf Task, Project oder später Group zeigen)
            $table->morphs('commentable');
            // Der Text des Kommentars
            $table->text('content');
            // Optional: Wer hat kommentiert? (Für später, wenn Login da ist)
            $table->foreignId('user_id')->nullable()->constrained()->onDelete('cascade');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('comments');
    }
};