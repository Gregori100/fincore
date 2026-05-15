<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('categories', function (Blueprint $table) {
            // PK + FK user_id como UUID (consistente con users/accounts/journal_entries).
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();

            $table->string('name', 80);
            $table->enum('applies_to', ['income', 'expense', 'both']);

            // Slugs validados contra catálogo en CategoryDefaults; guardamos texto
            // corto para mantener flexibilidad si se amplía la paleta o iconos.
            $table->string('color_slug', 30);
            $table->string('icon_slug', 40);

            $table->timestamps();
            $table->softDeletes();

            $table->index(['user_id', 'deleted_at']);
            $table->index(['user_id', 'applies_to']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('categories');
    }
};
