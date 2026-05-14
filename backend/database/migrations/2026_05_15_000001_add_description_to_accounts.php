<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('accounts', function (Blueprint $table) {
            // Anotación libre por cuenta. Validación de longitud (max 200)
            // se aplica a nivel Action/Controller; la columna es text para
            // permitir contenido sin tope físico estricto y mantener flexibilidad.
            $table->text('description')->nullable()->after('name');
        });
    }

    public function down(): void
    {
        Schema::table('accounts', function (Blueprint $table) {
            $table->dropColumn('description');
        });
    }
};
