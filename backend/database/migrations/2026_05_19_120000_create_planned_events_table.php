<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('planned_events', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('kind', 32);
            $table->decimal('amount', 12, 2);
            $table->foreignUuid('account_origin_id')->nullable()->constrained('accounts')->restrictOnDelete();
            $table->foreignUuid('account_destination_id')->nullable()->constrained('accounts')->restrictOnDelete();
            $table->foreignUuid('category_id')->nullable()->constrained('categories')->nullOnDelete();
            $table->string('description', 200)->nullable();
            $table->string('recurrence_type', 16);
            $table->smallInteger('recurrence_day')->nullable();
            $table->date('start_date');
            $table->date('end_date')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'start_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('planned_events');
    }
};
