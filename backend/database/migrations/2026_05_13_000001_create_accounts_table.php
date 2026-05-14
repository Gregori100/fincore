<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('accounts', function (Blueprint $table) {
            // PK como UUID v4 (ver create_users_table). user_id también es uuid
            // para que la FK encaje con users.id.
            $table->uuid('id')->primary();
            $table->uuid('user_id')->nullable();
            $table->string('name');
            $table->enum('type', ['cash', 'debit', 'credit']);
            $table->boolean('is_protected')->default(false);

            $table->decimal('credit_limit', 12, 2)->nullable();
            $table->unsignedTinyInteger('closing_day')->nullable();
            $table->unsignedTinyInteger('payment_day')->nullable();
            $table->decimal('interest_rate', 6, 4)->nullable();
            $table->decimal('minimum_payment_pct', 6, 4)->nullable();

            $table->timestamps();

            $table->index(['user_id', 'type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('accounts');
    }
};
