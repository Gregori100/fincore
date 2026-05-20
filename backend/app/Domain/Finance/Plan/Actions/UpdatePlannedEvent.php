<?php

namespace App\Domain\Finance\Plan\Actions;

use App\Domain\Finance\Exceptions\ImmutableJournalField;
use App\Domain\Finance\Plan\Exceptions\InvalidRecurrence;
use App\Domain\Finance\Support\JournalKindContract;
use App\Models\PlannedEvent;
use Illuminate\Support\Facades\DB;

class UpdatePlannedEvent
{
    private const EDITABLE_FIELDS = [
        'amount',
        'account_origin_id',
        'account_destination_id',
        'category_id',
        'description',
        'recurrence_type',
        'recurrence_day',
        'start_date',
        'end_date',
    ];

    /**
     * @return array{event: PlannedEvent, removed_overrides: int}
     */
    public static function execute(string $userId, string $eventId, array $changes): array
    {
        $rejected = array_diff(array_keys($changes), self::EDITABLE_FIELDS);
        if (! empty($rejected)) {
            throw new ImmutableJournalField('No se puede modificar: '.implode(', ', $rejected));
        }

        $event = PlannedEvent::where('id', $eventId)
            ->where('user_id', $userId)
            ->firstOrFail();

        $update = array_intersect_key($changes, array_flip(self::EDITABLE_FIELDS));

        if (array_key_exists('amount', $update)) {
            $update['amount'] = CreatePlannedEvent::normalizeAmount($update['amount']);
        }

        if (array_key_exists('description', $update)) {
            $update['description'] = CreatePlannedEvent::normalizeDescription($update['description']);
        }

        $newType = $update['recurrence_type'] ?? $event->recurrence_type;
        $newDay = array_key_exists('recurrence_day', $update)
            ? ($update['recurrence_day'] !== null ? (int) $update['recurrence_day'] : null)
            : $event->recurrence_day;
        CreatePlannedEvent::validateRecurrence($newType, $newDay);
        if ($newType === PlannedEvent::RECURRENCE_ONE_OFF) {
            $update['recurrence_day'] = null;
        } else {
            $update['recurrence_day'] = $newDay;
        }

        if (array_key_exists('start_date', $update)) {
            $update['start_date'] = CreatePlannedEvent::parseDateRequired($update['start_date'], 'start_date');
            CreatePlannedEvent::validateDateRange($update['start_date'], 'start_date');
        }
        if (array_key_exists('end_date', $update)) {
            $update['end_date'] = CreatePlannedEvent::parseDateOptional($update['end_date']);
            if ($update['end_date'] !== null) {
                CreatePlannedEvent::validateDateRange($update['end_date'], 'end_date');
            }
        }

        $finalStart = $update['start_date'] ?? $event->start_date;
        $finalEnd = array_key_exists('end_date', $update) ? $update['end_date'] : $event->end_date;
        if ($finalEnd !== null && $finalEnd->lt($finalStart)) {
            throw new InvalidRecurrence('end_date no puede ser anterior a start_date.');
        }

        $touchOrigin = array_key_exists('account_origin_id', $update);
        $touchDestination = array_key_exists('account_destination_id', $update);
        if ($touchOrigin || $touchDestination) {
            $finalOrigin = $touchOrigin ? $update['account_origin_id'] : $event->account_origin_id;
            $finalDestination = $touchDestination ? $update['account_destination_id'] : $event->account_destination_id;
            JournalKindContract::validateAccountsForKind($userId, $event->kind, $finalOrigin, $finalDestination);
        }

        if (array_key_exists('category_id', $update) && $update['category_id'] !== null) {
            CreatePlannedEvent::validateCategory($userId, $event->kind, $update['category_id']);
        }

        return DB::transaction(function () use ($event, $update) {
            $event->update($update);
            $event->refresh();

            // Tras la actualización, eliminar overrides cuya occurrence_date deja
            // de coincidir con una ocurrencia válida de la nueva regla.
            $removed = 0;
            foreach ($event->overrides()->get() as $override) {
                if (! $event->occursOn($override->occurrence_date)) {
                    $override->delete();
                    $removed++;
                }
            }

            return [
                'event' => $event->fresh(['origin', 'destination', 'category', 'overrides']),
                'removed_overrides' => $removed,
            ];
        });
    }
}
