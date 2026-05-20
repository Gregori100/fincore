<?php

namespace Tests\Feature\Plan;

use App\Domain\Finance\Exceptions\ImmutableJournalField;
use App\Domain\Finance\Plan\Actions\CreatePlannedEvent;
use App\Domain\Finance\Plan\Actions\CreatePlannedEventOverride;
use App\Domain\Finance\Plan\Actions\UpdatePlannedEvent;
use App\Models\Account;
use App\Models\JournalEntry;
use App\Models\PlannedEvent;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

class UpdatePlannedEventTest extends TestCase
{
    use RefreshDatabase;

    private function createUserWithEvent(): array
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

        return [$user, $event, $bolsa];
    }

    public function test_update_amount(): void
    {
        [$user, $event] = $this->createUserWithEvent();
        $result = UpdatePlannedEvent::execute($user->id, $event->id, ['amount' => 6500]);
        $this->assertEquals(6500.00, $result['event']->amount);
    }

    public function test_update_recurrence_day(): void
    {
        [$user, $event] = $this->createUserWithEvent();
        $result = UpdatePlannedEvent::execute($user->id, $event->id, ['recurrence_day' => 0]);
        $this->assertSame(0, $result['event']->recurrence_day);
    }

    public function test_update_description(): void
    {
        [$user, $event] = $this->createUserWithEvent();
        $result = UpdatePlannedEvent::execute($user->id, $event->id, ['description' => '  sueldo  ']);
        $this->assertSame('sueldo', $result['event']->description);
    }

    public function test_update_dates(): void
    {
        [$user, $event] = $this->createUserWithEvent();
        $start = Carbon::today()->addDay()->toDateString();
        $end = Carbon::today()->addMonths(3)->toDateString();
        $result = UpdatePlannedEvent::execute($user->id, $event->id, [
            'start_date' => $start,
            'end_date' => $end,
        ]);
        $this->assertSame($start, $result['event']->start_date->toDateString());
        $this->assertSame($end, $result['event']->end_date->toDateString());
    }

    public function test_rejects_kind_change(): void
    {
        [$user, $event] = $this->createUserWithEvent();
        $this->expectException(ImmutableJournalField::class);
        UpdatePlannedEvent::execute($user->id, $event->id, ['kind' => JournalEntry::KIND_EXPENSE]);
    }

    public function test_changing_recurrence_day_removes_orphan_overrides(): void
    {
        [$user, $event] = $this->createUserWithEvent();
        $nextFriday = $event->occurrencesBetween(Carbon::today(), Carbon::today()->addWeeks(3))->first();

        CreatePlannedEventOverride::execute($user->id, $event->id, [
            'occurrence_date' => $nextFriday->toDateString(),
            'amount' => 9999,
        ]);
        $this->assertSame(1, $event->overrides()->count());

        // Cambiamos a domingo (6); el override del viernes ya no aplica.
        $result = UpdatePlannedEvent::execute($user->id, $event->id, ['recurrence_day' => 6]);

        $this->assertSame(1, $result['removed_overrides']);
        $this->assertSame(0, $event->fresh()->overrides()->count());
    }

    public function test_rejects_other_users_event(): void
    {
        $userA = $this->createUserWithBolsa();
        [$userB, $event] = $this->createUserWithEvent();

        $this->expectException(ModelNotFoundException::class);
        UpdatePlannedEvent::execute($userA->id, $event->id, ['amount' => 9999]);
    }

    public function test_update_account_validates_kind_contract(): void
    {
        [$user, $event] = $this->createUserWithEvent();
        $card = Account::factory()->credit()->for($user)->create();

        $this->expectException(\App\Domain\Finance\Exceptions\InvalidAccountType::class);
        // income con destino credit no es válido.
        UpdatePlannedEvent::execute($user->id, $event->id, ['account_destination_id' => $card->id]);
    }
}
