<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
{
    Schema::table('task_attachments', function (Blueprint $table) {
        // 1. project_id hinzufügen (muss nullable sein, da Dateien auch nur an Tasks hängen können)
        $table->foreignId('project_id')->nullable()->constrained()->cascadeOnDelete();
        
        // 2. task_id optional machen (falls eine Datei nur am Projekt hängt)
        $table->unsignedBigInteger('task_id')->nullable()->change();
    });

    // Optional: Tabelle von 'task_attachments' in 'attachments' umbenennen, damit es sauber aussieht
    Schema::rename('task_attachments', 'attachments');
}

public function down(): void
{
    Schema::rename('attachments', 'task_attachments');
    
    Schema::table('task_attachments', function (Blueprint $table) {
        $table->dropColumn('project_id');
        $table->unsignedBigInteger('task_id')->nullable(false)->change();
    });
}
};
