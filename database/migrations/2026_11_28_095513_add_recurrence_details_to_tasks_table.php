<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up()
{
    Schema::table('tasks', function (Blueprint $table) {
        // 1 = Montag, 7 = Sonntag (für wöchentlich)
        $table->integer('recurrence_day_of_week')->nullable()->after('recurrence');
        // 1 bis 31 (für monatlich)
        $table->integer('recurrence_day_of_month')->nullable()->after('recurrence_day_of_week');
    });
}

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('tasks', function (Blueprint $table) {
            //
        });
    }
};
