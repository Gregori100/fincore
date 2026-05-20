<?php

namespace App\Domain\Finance\Plan\Actions;

use App\Models\PlannedEventOverride;

class DeletePlannedEventOverride
{
    public static function execute(string $userId, string $overrideId): void
    {
        $override = PlannedEventOverride::whereHas('event', function ($q) use ($userId) {
            $q->where('user_id', $userId);
        })->where('id', $overrideId)->firstOrFail();

        $override->delete();
    }
}
