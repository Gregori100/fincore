<?php

namespace Tests\Feature\Plan;

use App\Domain\Finance\Plan\Actions\CreatePlannedEvent;
use App\Domain\Finance\Plan\Actions\CreatePlannedEventOverride;
use App\Domain\Finance\Plan\Actions\DeletePlannedEventOverride;
use App\Domain\Finance\Plan\Actions\UpdatePlannedEventOverride;
use App\Domain\Finance\Plan\Exceptions\InvalidRecurrence;
use App\Domain\Finance\Plan\Exceptions\OverrideOnNonOccurrence;
use App\Models\Account;
use App\Models\JournalEntry;
use App\Models\PlannedEvent;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

class PlannedEventOverrideTest extends TestCase
{
    use RefreshDatabase;

    private function setupWeeklyEvent(): array
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $event = CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 5000,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);
        $firstOccurrence = $event->occurrencesBetween(Carbon::today(), Carbon::today()->addWeeks(4))->first();

        return [$user, $event, $firstOccurrence];
    }

    public function test_create_override_with_amount(): void
    {
        [$user, $event, $first] = $this->setupWeeklyEvent();

        $override = CreatePlannedEventOverride::execute($user->id, $event->id, [
            'occurrence_date' => $first->toDateString(),
            'amount' => 9999,
        ]);

        $this->assertEquals(9999.00, $override->amount);
        $this->assertFalse($override->is_skipped);
    }

    public function test_create_override_skipped(): void
    {
        [$user, $event, $first] = $this->setupWeeklyEvent();

        $override = CreatePlannedEventOverride::execute($user->id, $event->id, [
            'occurrence_date' => $first->toDateString(),
            'is_skipped' => true,
        ]);

        $this->assertTrue($override->is_skipped);
        $this->assertNull($override->amount);
    }

    public function test_create_override_skipped_ignores_amount(): void
    {
        [$user, $event, $first] = $this->setupWeeklyEvent();

        $override = CreatePlannedEventOverride::execute($user->id, $event->id, [
            'occurrence_date' => $first->toDateString(),
            'is_skipped' => true,
            'amount' => 5000,
        ]);

        $this->assertTrue($override->is_skipped);
        $this->assertNull($override->amount);
    }

    public function test_rejects_override_on_one_off(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $event = CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 1000,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_ONE_OFF,
            'start_date' => Carbon::today()->addDays(5)->toDateString(),
        ]);

        $this->expectException(InvalidRecurrence::class);
        CreatePlannedEventOverride::execute($user->id, $event->id, [
            'occurrence_date' => Carbon::today()->addDays(5)->toDateString(),
            'amount' => 500,
        ]);
    }

    public function test_rejects_override_on_non_occurrence_date(): void
    {
        [$user, $event, $first] = $this->setupWeeklyEvent();
        // Una fecha que cae en martes (no en viernes).
        $tuesday = $first->copy()->next(Carbon::TUESDAY);

        $this->expectException(OverrideOnNonOccurrence::class);
        CreatePlannedEventOverride::execute($user->id, $event->id, [
            'occurrence_date' => $tuesday->toDateString(),
            'amount' => 500,
        ]);
    }

    public function test_rejects_override_without_amount_or_skip(): void
    {
        [$user, $event, $first] = $this->setupWeeklyEvent();

        $this->expectException(InvalidRecurrence::class);
        CreatePlannedEventOverride::execute($user->id, $event->id, [
            'occurrence_date' => $first->toDateString(),
        ]);
    }

    public function test_duplicate_override_fails(): void
    {
        [$user, $event, $first] = $this->setupWeeklyEvent();
        CreatePlannedEventOverride::execute($user->id, $event->id, [
            'occurrence_date' => $first->toDateString(),
            'amount' => 100,
        ]);

        $this->expectException(QueryException::class);
        CreatePlannedEventOverride::execute($user->id, $event->id, [
            'occurrence_date' => $first->toDateString(),
            'amount' => 200,
        ]);
    }

    public function test_update_override_amount(): void
    {
        [$user, $event, $first] = $this->setupWeeklyEvent();
        $override = CreatePlannedEventOverride::execute($user->id, $event->id, [
            'occurrence_date' => $first->toDateString(),
            'amount' => 100,
        ]);

        $updated = UpdatePlannedEventOverride::execute($user->id, $override->id, ['amount' => 250]);
        $this->assertEquals(250.00, $updated->amount);
    }

    public function test_delete_override(): void
    {
        [$user, $event, $first] = $this->setupWeeklyEvent();
        $override = CreatePlannedEventOverride::execute($user->id, $event->id, [
            'occurrence_date' => $first->toDateString(),
            'amount' => 100,
        ]);

        DeletePlannedEventOverride::execute($user->id, $override->id);

        $this->assertNull($override->fresh());
    }

    public function test_other_user_cannot_touch_override(): void
    {
        [$user, $event, $first] = $this->setupWeeklyEvent();
        $override = CreatePlannedEventOverride::execute($user->id, $event->id, [
            'occurrence_date' => $first->toDateString(),
            'amount' => 100,
        ]);
        $stranger = $this->createUserWithBolsa();

        $this->expectException(ModelNotFoundException::class);
        UpdatePlannedEventOverride::execute($stranger->id, $override->id, ['amount' => 999]);
    }
}
