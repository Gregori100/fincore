<?php

namespace App\Domain\Finance\Plan\Actions;

use App\Models\PlannedEvent;
use Illuminate\Support\Facades\DB;

class ClearPlannedEvents
{
    /**
     * Borra todos los eventos planeados del usuario. Los overrides asociados se
     * eliminan en cascada por la FK definida en la migración.
     *
     * @return int  cantidad de eventos eliminados
     */
    public static function execute(string $userId): int
    {
        return DB::transaction(function () use ($userId) {
            return PlannedEvent::where('user_id', $userId)->delete();
        });
    }
}
