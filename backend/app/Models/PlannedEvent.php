<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

class PlannedEvent extends Model
{
    use HasFactory;
    use HasUuids;

    public const RECURRENCE_ONE_OFF = 'one_off';
    public const RECURRENCE_WEEKLY = 'weekly';
    public const RECURRENCE_MONTHLY = 'monthly';

    public const RECURRENCE_TYPES = [
        self::RECURRENCE_ONE_OFF,
        self::RECURRENCE_WEEKLY,
        self::RECURRENCE_MONTHLY,
    ];

    public const KINDS = [
        JournalEntry::KIND_INCOME,
        JournalEntry::KIND_EXPENSE,
        JournalEntry::KIND_CREDIT_EXPENSE,
        JournalEntry::KIND_DEBT_PAYMENT,
    ];

    protected $fillable = [
        'user_id',
        'kind',
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

    protected $casts = [
        'amount' => 'decimal:2',
        'recurrence_day' => 'integer',
        'start_date' => 'date',
        'end_date' => 'date',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function origin(): BelongsTo
    {
        return $this->belongsTo(Account::class, 'account_origin_id')->withTrashed();
    }

    public function destination(): BelongsTo
    {
        return $this->belongsTo(Account::class, 'account_destination_id')->withTrashed();
    }

    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    public function overrides(): HasMany
    {
        return $this->hasMany(PlannedEventOverride::class);
    }

    /**
     * Genera las fechas de ocurrencia de la regla en el rango cerrado [from, to].
     * Para `weekly`, devuelve cada coincidencia con `recurrence_day` (0=lunes
     * .. 6=domingo, ISO 8601). Para `monthly`, devuelve la coincidencia con
     * `recurrence_day` clampeada al último día del mes si éste no existe (ej.
     * day=31 en febrero retorna 28/29). Para `one_off`, devuelve solo
     * `start_date` si cae dentro del rango.
     */
    public function occurrencesBetween(Carbon $from, Carbon $to): Collection
    {
        $from = $from->copy()->startOfDay();
        $to = $to->copy()->startOfDay();

        // El comienzo efectivo es el mayor entre start_date y from.
        $start = $this->start_date->copy()->startOfDay();
        if ($start->lt($from)) {
            $start = $from->copy();
        }

        // El fin efectivo es el menor entre end_date (si existe) y to.
        $end = $to->copy();
        if ($this->end_date !== null && $this->end_date->lt($end)) {
            $end = $this->end_date->copy()->startOfDay();
        }

        if ($start->gt($end)) {
            return collect();
        }

        return match ($this->recurrence_type) {
            self::RECURRENCE_ONE_OFF => $this->oneOffOccurrence($start, $end),
            self::RECURRENCE_WEEKLY => $this->weeklyOccurrences($start, $end),
            self::RECURRENCE_MONTHLY => $this->monthlyOccurrences($start, $end),
            default => collect(),
        };
    }

    /**
     * Comprueba si una fecha específica es una ocurrencia válida de la regla.
     * Usado por la Action de override para rechazar fechas que no caen en el
     * patrón.
     */
    public function occursOn(Carbon $date): bool
    {
        $day = $date->copy()->startOfDay();

        if ($this->start_date->copy()->startOfDay()->gt($day)) {
            return false;
        }
        if ($this->end_date !== null && $this->end_date->copy()->startOfDay()->lt($day)) {
            return false;
        }

        return match ($this->recurrence_type) {
            self::RECURRENCE_ONE_OFF => $this->start_date->copy()->startOfDay()->eq($day),
            self::RECURRENCE_WEEKLY => $this->isoDayOfWeek($day) === $this->recurrence_day,
            self::RECURRENCE_MONTHLY => $this->dayMatchesMonthlyRule($day),
            default => false,
        };
    }

    private function oneOffOccurrence(Carbon $start, Carbon $end): Collection
    {
        $only = $this->start_date->copy()->startOfDay();
        if ($only->between($start, $end)) {
            return collect([$only]);
        }

        return collect();
    }

    private function weeklyOccurrences(Carbon $start, Carbon $end): Collection
    {
        $occurrences = collect();
        $cursor = $start->copy();
        // Avanzar hasta la primera ocurrencia del recurrence_day desde el start.
        while ($this->isoDayOfWeek($cursor) !== $this->recurrence_day) {
            $cursor->addDay();
            if ($cursor->gt($end)) {
                return $occurrences;
            }
        }
        while ($cursor->lte($end)) {
            $occurrences->push($cursor->copy());
            $cursor->addWeek();
        }

        return $occurrences;
    }

    private function monthlyOccurrences(Carbon $start, Carbon $end): Collection
    {
        $occurrences = collect();
        // Empezamos por el primer mes que pueda contener una ocurrencia.
        $cursorMonth = $start->copy()->startOfMonth();
        while ($cursorMonth->lte($end)) {
            $day = $this->monthlyOccurrenceInMonth($cursorMonth);
            if ($day->between($start, $end)) {
                $occurrences->push($day);
            }
            $cursorMonth->addMonth();
        }

        return $occurrences;
    }

    private function monthlyOccurrenceInMonth(Carbon $month): Carbon
    {
        $last = $month->copy()->endOfMonth()->day;
        $day = min($this->recurrence_day, $last);

        return $month->copy()->setDay($day)->startOfDay();
    }

    private function dayMatchesMonthlyRule(Carbon $day): bool
    {
        return $this->monthlyOccurrenceInMonth($day->copy()->startOfMonth())->eq($day);
    }

    /**
     * ISO 8601: 0 = lunes, 6 = domingo. Carbon expone `dayOfWeekIso` con 1..7,
     * con 1 = lunes y 7 = domingo. Normalizamos restando 1.
     */
    private function isoDayOfWeek(Carbon $date): int
    {
        return $date->dayOfWeekIso - 1;
    }
}
