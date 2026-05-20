<?php

namespace Tests\Feature\Plan;

use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Plan\Actions\CreatePlannedEvent;
use App\Domain\Finance\Plan\Actions\CreatePlannedEventOverride;
use App\Domain\Finance\Plan\Services\PlanProjectionService;
use App\Models\Account;
use App\Models\JournalEntry;
use App\Models\PlannedEvent;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

class PlanProjectionServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_no_events_returns_constant_series(): void
    {
        $user = $this->createUserWithBolsa();
        RegisterIncome::execute($user->id, $user->accounts()->where('type', Account::TYPE_CASH)->first()->id, 1000);

        $projection = (new PlanProjectionService($user->id))->project();
        $this->assertSame([], $projection['events']);
        $this->assertSame(1000.0, $projection['accounts'][0]['initial_balance']);
        $this->assertSame(1000.0, $projection['accounts'][0]['final_balance']);
    }

    public function test_weekly_income_increases_balance(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->first();
        CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 1000,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => Carbon::today()->dayOfWeekIso - 1, // hoy
            'start_date' => Carbon::today()->toDateString(),
        ]);

        $projection = (new PlanProjectionService($user->id))->project();
        $this->assertGreaterThan(0, count($projection['events']));
        $this->assertGreaterThan($projection['accounts'][0]['initial_balance'], $projection['accounts'][0]['final_balance']);
    }

    public function test_weekly_debt_payment_decreases_debt(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->first();
        $card = Account::factory()->credit()->for($user)->create();
        RegisterIncome::execute($user->id, $bolsa->id, 50000);
        RegisterCreditExpense::execute($user->id, $card->id, 30000);

        CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_DEBT_PAYMENT,
            'amount' => 3000,
            'account_origin_id' => $bolsa->id,
            'account_destination_id' => $card->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => Carbon::today()->dayOfWeekIso - 1,
            'start_date' => Carbon::today()->toDateString(),
        ]);

        $projection = (new PlanProjectionService($user->id))->project();
        $cardSummary = collect($projection['accounts'])->firstWhere('id', $card->id);
        $this->assertLessThan(30000, $cardSummary['final_balance']);
    }

    public function test_monthly_clamp_to_last_day_of_february(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->first();
        $event = CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 1000,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_MONTHLY,
            'recurrence_day' => 31,
            'start_date' => Carbon::create(2027, 1, 1)->toDateString(),
            'end_date' => Carbon::create(2027, 3, 31)->toDateString(),
        ]);

        $occurrences = $event->occurrencesBetween(
            Carbon::create(2027, 1, 1),
            Carbon::create(2027, 3, 31),
        );

        $februaryOccurrence = $occurrences->first(fn (Carbon $d) => $d->month === 2);
        $this->assertNotNull($februaryOccurrence);
        $this->assertSame(28, $februaryOccurrence->day);
    }

    public function test_one_off_in_future_appears_once(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->first();
        CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_EXPENSE,
            'amount' => 1000,
            'account_origin_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_ONE_OFF,
            'start_date' => Carbon::today()->addDays(10)->toDateString(),
        ]);

        $projection = (new PlanProjectionService($user->id))->project();
        $oneOffEvents = collect($projection['events'])->where('kind', JournalEntry::KIND_EXPENSE);
        $this->assertCount(1, $oneOffEvents);
    }

    public function test_one_off_in_past_does_not_appear(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->first();
        CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_EXPENSE,
            'amount' => 1000,
            'account_origin_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_ONE_OFF,
            'start_date' => Carbon::today()->subDays(10)->toDateString(),
        ]);

        $projection = (new PlanProjectionService($user->id))->project();
        $this->assertSame([], $projection['events']);
    }

    public function test_override_changes_amount(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->first();
        $event = CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 1000,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => Carbon::today()->dayOfWeekIso - 1,
            'start_date' => Carbon::today()->toDateString(),
        ]);
        $first = $event->occurrencesBetween(Carbon::today(), Carbon::today()->addWeeks(1))->first();
        CreatePlannedEventOverride::execute($user->id, $event->id, [
            'occurrence_date' => $first->toDateString(),
            'amount' => 5000,
        ]);

        $projection = (new PlanProjectionService($user->id))->project();
        $override = collect($projection['events'])->firstWhere('source', 'override');
        $this->assertNotNull($override);
        $this->assertEquals(5000.0, $override['amount']);
    }

    public function test_override_skipped_does_not_affect_balance(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->first();
        $event = CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 1000,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => Carbon::today()->dayOfWeekIso - 1,
            'start_date' => Carbon::today()->toDateString(),
            'end_date' => Carbon::today()->addDays(1)->toDateString(),
        ]);
        $first = $event->occurrencesBetween(Carbon::today(), Carbon::today()->addDays(1))->first();
        CreatePlannedEventOverride::execute($user->id, $event->id, [
            'occurrence_date' => $first->toDateString(),
            'is_skipped' => true,
        ]);

        $projection = (new PlanProjectionService($user->id))->project();
        $this->assertSame(
            $projection['accounts'][0]['initial_balance'],
            $projection['accounts'][0]['final_balance'],
        );
        $skippedEvent = collect($projection['events'])->firstWhere('skipped', true);
        $this->assertNotNull($skippedEvent);
    }

    public function test_overpay_marks_warning(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->first();
        $card = Account::factory()->credit()->for($user)->create();
        RegisterIncome::execute($user->id, $bolsa->id, 50000);
        RegisterCreditExpense::execute($user->id, $card->id, 500);
        CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_DEBT_PAYMENT,
            'amount' => 1000,
            'account_origin_id' => $bolsa->id,
            'account_destination_id' => $card->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_ONE_OFF,
            'start_date' => Carbon::today()->addDays(3)->toDateString(),
        ]);

        $projection = (new PlanProjectionService($user->id))->project();
        $event = collect($projection['events'])->first();
        $this->assertContains('overpay', $event['warnings']);
    }

    public function test_event_for_archived_account_is_skipped(): void
    {
        $user = $this->createUserWithBolsa();
        $debit = Account::factory()->debit()->for($user)->create();
        $event = CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 1000,
            'account_destination_id' => $debit->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => Carbon::today()->dayOfWeekIso - 1,
            'start_date' => Carbon::today()->toDateString(),
        ]);

        // Archivar la cuenta destino.
        $debit->delete();

        $projection = (new PlanProjectionService($user->id))->project();
        $first = collect($projection['events'])->first();
        $this->assertNotNull($first);
        $this->assertTrue($first['skipped']);
        $this->assertContains('archived_account', $first['warnings']);
    }

    public function test_horizon_inclusive_of_end_date(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->first();
        $projection = (new PlanProjectionService($user->id))->project();
        $this->assertSame(Carbon::today()->toDateString(), $projection['horizon']['from']);
        $this->assertSame(Carbon::today()->addMonths(6)->toDateString(), $projection['horizon']['to']);
    }

    public function test_events_are_ordered_by_date(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->first();
        CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 1000,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_ONE_OFF,
            'start_date' => Carbon::today()->addDays(20)->toDateString(),
        ]);
        CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_EXPENSE,
            'amount' => 500,
            'account_origin_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_ONE_OFF,
            'start_date' => Carbon::today()->addDays(5)->toDateString(),
        ]);

        $projection = (new PlanProjectionService($user->id))->project();
        $dates = collect($projection['events'])->pluck('date')->all();
        $sorted = $dates;
        sort($sorted);
        $this->assertSame($sorted, $dates);
    }

    public function test_projection_scoped_by_user(): void
    {
        $userA = $this->createUserWithBolsa();
        $userB = $this->createUserWithBolsa();
        $bolsaB = $userB->accounts()->where('type', Account::TYPE_CASH)->first();
        CreatePlannedEvent::execute($userB->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 1000,
            'account_destination_id' => $bolsaB->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_ONE_OFF,
            'start_date' => Carbon::today()->addDays(10)->toDateString(),
        ]);

        $projectionA = (new PlanProjectionService($userA->id))->project();
        $this->assertSame([], $projectionA['events']);
    }
}
