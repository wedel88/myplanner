<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
public function up()
{
    Schema::table('projects', function (Blueprint $table) {
        // Falls noch nicht vorhanden, fügen wir eine Beschreibung hinzu
        if (!Schema::hasColumn('projects', 'description')) {
            $table->text('description')->nullable();
        }
        // Feld für die manuelle Sortierung/Priorisierung
        if (!Schema::hasColumn('projects', 'sort_order')) {
            $table->integer('sort_order')->default(0);
        }
    });
}

public function down()
{
    Schema::table('projects', function (Blueprint $table) {
        $table->dropColumn(['description', 'sort_order']);
    });
}
};