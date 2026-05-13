<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('journal_entries', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('user_id')->nullable();
            $table->enum('kind', [
                'income',
                'expense',
                'credit_expense',
                'debt_payment',
                'transfer',
                'adjustment',
            ]);
            $table->decimal('amount', 12, 2);
            $table->foreignId('account_origin_id')->nullable()->constrained('accounts');
            $table->foreignId('account_destination_id')->nullable()->constrained('accounts');
            $table->string('description')->nullable();
            $table->timestamp('occurred_at');
            $table->timestamps();

            $table->index(['user_id', 'occurred_at']);
            $table->index('kind');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('journal_entries');
    }
};
