<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('categories', function (Blueprint $table) {
            // Tope mensual de gasto para presupuestos por categoría.
            // Nullable: si es null la categoría no tiene presupuesto configurado.
            // Solo aplica a categorías con applies_to ∈ {expense, both} hoy;
            // si applies_to=income el valor se persiste pero no se usa en reportes.
            $table->decimal('monthly_limit', 12, 2)->nullable()->after('icon_slug');
        });
    }

    public function down(): void
    {
        Schema::table('categories', function (Blueprint $table) {
            $table->dropColumn('monthly_limit');
        });
    }
};
