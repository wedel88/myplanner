<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('containers', function (Blueprint $table) {
            // Die neue Spalte für den Force-Status (kann leer sein)
            $table->string('force_status')->nullable()->after('name');
        });
    }

    public function down(): void
    {
        Schema::table('containers', function (Blueprint $table) {
            $table->dropColumn('force_status');
        });
    }
};
