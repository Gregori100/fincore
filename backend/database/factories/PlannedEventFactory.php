<?php

namespace Database\Factories;

use App\Models\JournalEntry;
use App\Models\PlannedEvent;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<PlannedEvent>
 */
class PlannedEventFactory extends Factory
{
    protected $model = PlannedEvent::class;

    public function definition(): array
    {
        return [
            'kind' => JournalEntry::KIND_EXPENSE,
            'amount' => 500.00,
            'account_origin_id' => null,
            'account_destination_id' => null,
            'category_id' => null,
            'description' => null,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4, // viernes (ISO: 0 lun .. 6 dom)
            'start_date' => now()->toDateString(),
            'end_date' => null,
        ];
    }

    public function weekly(int $day = 4): self
    {
        return $this->state(fn () => [
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => $day,
        ]);
    }

    public function monthly(int $day = 1): self
    {
        return $this->state(fn () => [
            'recurrence_type' => PlannedEvent::RECURRENCE_MONTHLY,
            'recurrence_day' => $day,
        ]);
    }

    public function oneOff(): self
    {
        return $this->state(fn () => [
            'recurrence_type' => PlannedEvent::RECURRENCE_ONE_OFF,
            'recurrence_day' => null,
        ]);
    }

    public function income(): self
    {
        return $this->state(fn () => ['kind' => JournalEntry::KIND_INCOME]);
    }

    public function expense(): self
    {
        return $this->state(fn () => ['kind' => JournalEntry::KIND_EXPENSE]);
    }

    public function creditExpense(): self
    {
        return $this->state(fn () => ['kind' => JournalEntry::KIND_CREDIT_EXPENSE]);
    }

    public function debtPayment(): self
    {
        return $this->state(fn () => ['kind' => JournalEntry::KIND_DEBT_PAYMENT]);
    }
}
