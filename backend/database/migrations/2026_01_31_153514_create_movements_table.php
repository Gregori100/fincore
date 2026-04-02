<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('movements', function (Blueprint $table) {
            $table->id();
            $table->enum('type', [
                'income',
                'expense',
                'credit_expense',
                'debt_payment',
                'adjustment'
            ]);
            $table->decimal('amount', 12, 2);
            $table->foreignId('debt_id')->nullable()->constrained('debts');
            $table->string('description')->nullable();
            $table->timestamp('occurred_at');
            $table->timestamps();

            $table->index('type');
            $table->index('debt_id');
            $table->index('occurred_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('movements');
    }
};
