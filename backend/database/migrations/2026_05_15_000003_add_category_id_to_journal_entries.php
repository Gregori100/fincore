<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('journal_entries', function (Blueprint $table) {
            // nullOnDelete: si una categoría se borra (hard delete), los entries
            // pierden la referencia pero conservan el resto de su información.
            // Para soft delete (archivar), el category_id queda intacto.
            $table->foreignUuid('category_id')
                ->nullable()
                ->after('description')
                ->constrained('categories')
                ->nullOnDelete();

            $table->index('category_id');
        });
    }

    public function down(): void
    {
        Schema::table('journal_entries', function (Blueprint $table) {
            $table->dropForeign(['category_id']);
            $table->dropIndex(['category_id']);
            $table->dropColumn('category_id');
        });
    }
};
