<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('planned_event_overrides', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignUuid('planned_event_id')->constrained('planned_events')->cascadeOnDelete();
            $table->date('occurrence_date');
            $table->decimal('amount', 12, 2)->nullable();
            $table->boolean('is_skipped')->default(false);
            $table->timestamps();

            $table->unique(['planned_event_id', 'occurrence_date']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('planned_event_overrides');
    }
};
