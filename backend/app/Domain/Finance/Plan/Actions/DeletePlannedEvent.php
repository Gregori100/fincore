<?php

namespace App\Domain\Finance\Plan\Actions;

use App\Models\PlannedEvent;

class DeletePlannedEvent
{
    public static function execute(string $userId, string $eventId): void
    {
        $event = PlannedEvent::where('id', $eventId)
            ->where('user_id', $userId)
            ->firstOrFail();

        // Hard delete. Los overrides asociados se borran en cascada por la FK
        // (ON DELETE CASCADE) declarada en la migración.
        $event->delete();
    }
}
