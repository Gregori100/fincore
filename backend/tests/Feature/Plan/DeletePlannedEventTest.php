<?php

namespace Tests\Feature\Plan;

use App\Domain\Finance\Plan\Actions\CreatePlannedEvent;
use App\Domain\Finance\Plan\Actions\CreatePlannedEventOverride;
use App\Domain\Finance\Plan\Actions\DeletePlannedEvent;
use App\Models\Account;
use App\Models\JournalEntry;
use App\Models\PlannedEvent;
use App\Models\PlannedEventOverride;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

class DeletePlannedEventTest extends TestCase
{
    use RefreshDatabase;

    public function test_delete_event_cascades_overrides(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        $event = CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 1000,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);
        $occurrence = $event->occurrencesBetween(Carbon::today(), Carbon::today()->addWeeks(2))->first();
        CreatePlannedEventOverride::execute($user->id, $event->id, [
            'occurrence_date' => $occurrence->toDateString(),
            'amount' => 1500,
        ]);

        $this->assertSame(1, PlannedEventOverride::count());

        DeletePlannedEvent::execute($user->id, $event->id);

        $this->assertSame(0, PlannedEvent::count());
        $this->assertSame(0, PlannedEventOverride::count());
    }

    public function test_delete_event_of_other_user_fails(): void
    {
        $userA = $this->createUserWithBolsa();
        $userB = $this->createUserWithBolsa();
        $bolsaB = $userB->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $event = CreatePlannedEvent::execute($userB->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 1000,
            'account_destination_id' => $bolsaB->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);

        $this->expectException(ModelNotFoundException::class);
        DeletePlannedEvent::execute($userA->id, $event->id);
    }

    public function test_delete_nonexistent_event_fails(): void
    {
        $user = $this->createUserWithBolsa();
        $this->expectException(ModelNotFoundException::class);
        DeletePlannedEvent::execute($user->id, '00000000-0000-0000-0000-000000000000');
    }
}
