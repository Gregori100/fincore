<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        // Limpia datos legacy con user_id null (solo existían en dev).
        // Driver-agnostic: funciona en Postgres y SQLite.
        // journal_entries primero (tiene FK a accounts), después accounts.
        DB::table('journal_entries')->delete();
        DB::table('accounts')->delete();

        Schema::table('accounts', function (Blueprint $table) {
            $table->foreign('user_id')->references('id')->on('users')->onDelete('cascade');
            $table->uuid('user_id')->nullable(false)->change();
        });
    }

    public function down(): void
    {
        Schema::table('accounts', function (Blueprint $table) {
            $table->dropForeign(['user_id']);
            $table->uuid('user_id')->nullable()->change();
        });
    }
};
