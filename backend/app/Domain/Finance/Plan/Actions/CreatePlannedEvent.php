<?php

namespace App\Domain\Finance\Plan\Actions;

use App\Domain\Finance\Exceptions\ImmutableJournalField;
use App\Domain\Finance\Exceptions\InvalidCategoryAppliesTo;
use App\Domain\Finance\Plan\Exceptions\InvalidRecurrence;
use App\Domain\Finance\Support\JournalKindContract;
use App\Models\Category;
use App\Models\JournalEntry;
use App\Models\PlannedEvent;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class CreatePlannedEvent
{
    private const MAX_DESCRIPTION_LENGTH = 200;
    private const MIN_DATE_OFFSET_YEARS = 1;
    private const MAX_DATE_OFFSET_YEARS = 5;

    /**
     * @param  array{kind:string, amount:int|float|string, account_origin_id?:?string, account_destination_id?:?string, category_id?:?string, description?:?string, recurrence_type:string, recurrence_day?:?int, start_date:string, end_date?:?string}  $data
     */
    public static function execute(string $userId, array $data): PlannedEvent
    {
        $kind = $data['kind'] ?? null;
        if (! in_array($kind, PlannedEvent::KINDS, true)) {
            throw new InvalidRecurrence('Kind no válido para evento planeado.');
        }

        $amount = self::normalizeAmount($data['amount'] ?? null);
        $recurrenceType = $data['recurrence_type'] ?? null;
        $recurrenceDay = isset($data['recurrence_day']) ? (int) $data['recurrence_day'] : null;

        self::validateRecurrence($recurrenceType, $recurrenceDay);

        $startDate = self::parseDateRequired($data['start_date'] ?? null, 'start_date');
        $endDate = self::parseDateOptional($data['end_date'] ?? null);

        if ($endDate !== null && $endDate->lt($startDate)) {
            throw new InvalidRecurrence('end_date no puede ser anterior a start_date.');
        }

        self::validateDateRange($startDate, 'start_date');
        if ($endDate !== null) {
            self::validateDateRange($endDate, 'end_date');
        }

        $originId = $data['account_origin_id'] ?? null;
        $destinationId = $data['account_destination_id'] ?? null;
        JournalKindContract::validateAccountsForKind($userId, $kind, $originId, $destinationId);

        $categoryId = $data['category_id'] ?? null;
        if ($categoryId !== null) {
            self::validateCategory($userId, $kind, $categoryId);
        }

        $description = self::normalizeDescription($data['description'] ?? null);

        return DB::transaction(function () use (
            $userId,
            $kind,
            $amount,
            $originId,
            $destinationId,
            $categoryId,
            $description,
            $recurrenceType,
            $recurrenceDay,
            $startDate,
            $endDate,
        ) {
            return PlannedEvent::create([
                'user_id' => $userId,
                'kind' => $kind,
                'amount' => $amount,
                'account_origin_id' => $originId,
                'account_destination_id' => $destinationId,
                'category_id' => $categoryId,
                'description' => $description,
                'recurrence_type' => $recurrenceType,
                'recurrence_day' => $recurrenceType === PlannedEvent::RECURRENCE_ONE_OFF ? null : $recurrenceDay,
                'start_date' => $startDate,
                'end_date' => $endDate,
            ]);
        });
    }

    public static function normalizeAmount(mixed $amount): float
    {
        if (! is_numeric($amount) || (float) $amount <= 0) {
            throw new ImmutableJournalField('El monto debe ser mayor a 0.');
        }

        return (float) $amount;
    }

    public static function validateRecurrence(?string $type, ?int $day): void
    {
        if (! in_array($type, PlannedEvent::RECURRENCE_TYPES, true)) {
            throw new InvalidRecurrence('Tipo de recurrencia inválido.');
        }

        switch ($type) {
            case PlannedEvent::RECURRENCE_ONE_OFF:
                // recurrence_day se ignora; no validar.
                break;
            case PlannedEvent::RECURRENCE_WEEKLY:
                if ($day === null || $day < 0 || $day > 6) {
                    throw new InvalidRecurrence('Para recurrencia semanal, recurrence_day debe estar entre 0 (lunes) y 6 (domingo).');
                }
                break;
            case PlannedEvent::RECURRENCE_MONTHLY:
                if ($day === null || $day < 1 || $day > 31) {
                    throw new InvalidRecurrence('Para recurrencia mensual, recurrence_day debe estar entre 1 y 31.');
                }
                break;
        }
    }

    public static function parseDateRequired(mixed $raw, string $field): Carbon
    {
        if ($raw === null || $raw === '') {
            throw new InvalidRecurrence("Falta {$field}.");
        }
        try {
            return Carbon::parse($raw)->startOfDay();
        } catch (\Exception) {
            throw new InvalidRecurrence("Fecha inválida en {$field}.");
        }
    }

    public static function parseDateOptional(mixed $raw): ?Carbon
    {
        if ($raw === null || $raw === '') {
            return null;
        }
        try {
            return Carbon::parse($raw)->startOfDay();
        } catch (\Exception) {
            throw new InvalidRecurrence('Fecha inválida en end_date.');
        }
    }

    public static function validateDateRange(Carbon $date, string $field): void
    {
        $min = Carbon::today()->subYears(self::MIN_DATE_OFFSET_YEARS);
        $max = Carbon::today()->addYears(self::MAX_DATE_OFFSET_YEARS);
        if ($date->lt($min) || $date->gt($max)) {
            throw new InvalidRecurrence("{$field} fuera del rango razonable.");
        }
    }

    public static function validateCategory(string $userId, string $kind, string $categoryId): void
    {
        $categoryKind = match ($kind) {
            JournalEntry::KIND_INCOME => Category::APPLIES_INCOME,
            JournalEntry::KIND_EXPENSE, JournalEntry::KIND_CREDIT_EXPENSE => Category::APPLIES_EXPENSE,
            default => null,
        };
        if ($categoryKind === null) {
            throw new InvalidCategoryAppliesTo();
        }
        $category = Category::where('id', $categoryId)
            ->where('user_id', $userId)
            ->first();
        if (! $category) {
            throw new InvalidCategoryAppliesTo('La categoría no existe o no te pertenece.');
        }
        if (! $category->appliesToKind($categoryKind)) {
            throw new InvalidCategoryAppliesTo();
        }
    }

    public static function normalizeDescription(mixed $raw): ?string
    {
        if ($raw === null) {
            return null;
        }
        $trimmed = trim((string) $raw);
        if ($trimmed === '') {
            return null;
        }
        if (mb_strlen($trimmed) > self::MAX_DESCRIPTION_LENGTH) {
            throw new ImmutableJournalField('La descripción no puede exceder '.self::MAX_DESCRIPTION_LENGTH.' caracteres.');
        }

        return $trimmed;
    }
}
