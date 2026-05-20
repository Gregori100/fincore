<?php

namespace App\Domain\Finance\Plan\Actions;

use App\Domain\Finance\Exceptions\ImmutableJournalField;
use App\Domain\Finance\Plan\Exceptions\InvalidRecurrence;
use App\Domain\Finance\Plan\Exceptions\OverrideOnNonOccurrence;
use App\Models\PlannedEvent;
use App\Models\PlannedEventOverride;
use Illuminate\Support\Carbon;

class CreatePlannedEventOverride
{
    /**
     * @param  array{occurrence_date:string, amount?:int|float|string|null, is_skipped?:bool}  $data
     */
    public static function execute(string $userId, string $eventId, array $data): PlannedEventOverride
    {
        $event = PlannedEvent::where('id', $eventId)
            ->where('user_id', $userId)
            ->firstOrFail();

        if ($event->recurrence_type === PlannedEvent::RECURRENCE_ONE_OFF) {
            throw new InvalidRecurrence('Los eventos puntuales no admiten overrides.');
        }

        $date = self::parseDate($data['occurrence_date'] ?? null);
        if (! $event->occursOn($date)) {
            throw new OverrideOnNonOccurrence();
        }

        $isSkipped = (bool) ($data['is_skipped'] ?? false);
        $amount = null;
        if (array_key_exists('amount', $data) && $data['amount'] !== null) {
            $amount = self::normalizeOverrideAmount($data['amount']);
        }

        if (! $isSkipped && $amount === null) {
            throw new InvalidRecurrence('El override debe especificar un monto o marcarse como saltado.');
        }

        return PlannedEventOverride::create([
            'planned_event_id' => $event->id,
            'occurrence_date' => $date,
            'amount' => $isSkipped ? null : $amount,
            'is_skipped' => $isSkipped,
        ]);
    }

    public static function parseDate(mixed $raw): Carbon
    {
        if ($raw === null || $raw === '') {
            throw new InvalidRecurrence('Falta occurrence_date.');
        }
        try {
            return Carbon::parse($raw)->startOfDay();
        } catch (\Exception) {
            throw new InvalidRecurrence('Fecha inválida en occurrence_date.');
        }
    }

    public static function normalizeOverrideAmount(mixed $amount): float
    {
        if (! is_numeric($amount) || (float) $amount <= 0) {
            throw new ImmutableJournalField('El monto del override debe ser mayor a 0.');
        }

        return (float) $amount;
    }
}
