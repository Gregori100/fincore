<?php

namespace App\Domain\Finance\Plan\Actions;

use App\Domain\Finance\Exceptions\ImmutableJournalField;
use App\Domain\Finance\Plan\Exceptions\InvalidRecurrence;
use App\Models\PlannedEventOverride;

class UpdatePlannedEventOverride
{
    private const EDITABLE_FIELDS = ['amount', 'is_skipped'];

    public static function execute(string $userId, string $overrideId, array $changes): PlannedEventOverride
    {
        $rejected = array_diff(array_keys($changes), self::EDITABLE_FIELDS);
        if (! empty($rejected)) {
            throw new ImmutableJournalField('No se puede modificar: '.implode(', ', $rejected));
        }

        $override = PlannedEventOverride::whereHas('event', function ($q) use ($userId) {
            $q->where('user_id', $userId);
        })->where('id', $overrideId)->firstOrFail();

        $update = array_intersect_key($changes, array_flip(self::EDITABLE_FIELDS));

        $isSkipped = array_key_exists('is_skipped', $update)
            ? (bool) $update['is_skipped']
            : (bool) $override->is_skipped;

        $amount = null;
        if (array_key_exists('amount', $update)) {
            $amount = $update['amount'];
            if ($amount !== null) {
                $amount = CreatePlannedEventOverride::normalizeOverrideAmount($amount);
            }
        } else {
            $amount = $override->amount !== null ? (float) $override->amount : null;
        }

        if (! $isSkipped && $amount === null) {
            throw new InvalidRecurrence('El override debe especificar un monto o marcarse como saltado.');
        }

        $update['is_skipped'] = $isSkipped;
        $update['amount'] = $isSkipped ? null : $amount;

        $override->update($update);

        return $override->fresh();
    }
}
