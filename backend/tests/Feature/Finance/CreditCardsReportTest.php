<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\CancelJournalEntry;
use App\Domain\Finance\Actions\DeleteAccount;
use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Reports\CreditCardsReport;
use App\Models\Account;
use App\Models\JournalEntry;
use Carbon\Carbon;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CreditCardsReportTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Carbon::setTestNow(); // limpia cualquier mock previo
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    private function freezeDate(string $date): void
    {
        Carbon::setTestNow($date);
        CarbonImmutable::setTestNow($date);
    }

    public function test_returns_empty_when_user_has_no_credit_cards(): void
    {
        $user = $this->createUserWithBolsa();

        $report = (new CreditCardsReport($user->id))->generate();

        $this->assertSame([], $report['cards']);
    }

    public function test_lists_active_credit_cards_with_basic_metrics(): void
    {
        $this->freezeDate('2026-05-22');
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create([
            'name' => 'Visa Oro',
            'credit_limit' => 30000,
            'closing_day' => 15,
            'payment_day' => 5,
            'minimum_payment_pct' => 0.05,
        ]);

        RegisterCreditExpense::execute($user->id, $card->id, 4000);

        $report = (new CreditCardsReport($user->id))->generate();

        $this->assertCount(1, $report['cards']);
        $c = $report['cards'][0];
        $this->assertSame('Visa Oro', $c['name']);
        $this->assertEqualsWithDelta(4000, $c['balance'], 0.01);
        $this->assertEqualsWithDelta(30000, $c['credit_limit'], 0.01);
        $this->assertEqualsWithDelta(26000, $c['available'], 0.01);
        $this->assertEqualsWithDelta(13.33, $c['utilization_pct'], 0.01);
    }

    public function test_days_to_closing_when_closing_day_not_yet_reached(): void
    {
        $this->freezeDate('2026-05-10'); // antes del closing_day=15
        $user = $this->createUserWithBolsa();
        Account::factory()->credit()->for($user)->create(['closing_day' => 15]);

        $report = (new CreditCardsReport($user->id))->generate();

        $this->assertSame('2026-05-15', $report['cards'][0]['next_closing_date']);
        $this->assertEquals(5, $report['cards'][0]['days_to_closing']);
    }

    public function test_days_to_closing_when_closing_day_already_passed(): void
    {
        $this->freezeDate('2026-05-22'); // después del closing_day=15
        $user = $this->createUserWithBolsa();
        Account::factory()->credit()->for($user)->create(['closing_day' => 15]);

        $report = (new CreditCardsReport($user->id))->generate();

        // El siguiente corte está en junio.
        $this->assertSame('2026-06-15', $report['cards'][0]['next_closing_date']);
        $this->assertEquals(24, $report['cards'][0]['days_to_closing']);
    }

    public function test_current_cycle_sums_credit_expense_between_last_closing_and_today(): void
    {
        $this->freezeDate('2026-05-22');
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create([
            'closing_day' => 15,
            'credit_limit' => 30000,
        ]);

        // Cargo en el ciclo previo (abril 20) y en el actual (mayo 18).
        $old = RegisterCreditExpense::execute($user->id, $card->id, 1000);
        $old->forceFill(['occurred_at' => '2026-04-20'])->save();
        $new = RegisterCreditExpense::execute($user->id, $card->id, 500);
        $new->forceFill(['occurred_at' => '2026-05-18'])->save();

        $report = (new CreditCardsReport($user->id))->generate();

        $cycle = $report['cards'][0]['current_cycle'];
        $this->assertSame('2026-05-16', $cycle['from']);
        $this->assertSame('2026-05-22', $cycle['to']);
        $this->assertEqualsWithDelta(500, $cycle['charges_total'], 0.01);
        $this->assertEquals(1, $cycle['charges_count']);
    }

    public function test_last_cycle_sums_charges_for_the_prior_cycle(): void
    {
        $this->freezeDate('2026-05-22');
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create(['closing_day' => 15, 'credit_limit' => 30000]);

        // Cargo en el ciclo cerrado (abril 16 → mayo 15).
        $e1 = RegisterCreditExpense::execute($user->id, $card->id, 800);
        $e1->forceFill(['occurred_at' => '2026-04-20'])->save();
        $e2 = RegisterCreditExpense::execute($user->id, $card->id, 200);
        $e2->forceFill(['occurred_at' => '2026-05-10'])->save();

        $report = (new CreditCardsReport($user->id))->generate();

        $last = $report['cards'][0]['last_cycle'];
        $this->assertSame('2026-04-16', $last['from']);
        $this->assertSame('2026-05-15', $last['to']);
        $this->assertEqualsWithDelta(1000, $last['charges_total'], 0.01);
        $this->assertEquals(2, $last['charges_count']);
    }

    public function test_cancelled_charges_are_excluded_from_cycle_totals(): void
    {
        $this->freezeDate('2026-05-22');
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create(['closing_day' => 15, 'credit_limit' => 30000]);

        $kept = RegisterCreditExpense::execute($user->id, $card->id, 200);
        $kept->forceFill(['occurred_at' => '2026-05-18'])->save();
        $cancel = RegisterCreditExpense::execute($user->id, $card->id, 999);
        $cancel->forceFill(['occurred_at' => '2026-05-18'])->save();
        CancelJournalEntry::execute($user->id, $cancel->id);

        $report = (new CreditCardsReport($user->id))->generate();

        $this->assertEqualsWithDelta(200, $report['cards'][0]['current_cycle']['charges_total'], 0.01);
    }

    public function test_minimum_payment_estimated_is_last_cycle_total_times_min_pct(): void
    {
        $this->freezeDate('2026-05-22');
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create([
            'closing_day' => 15,
            'credit_limit' => 30000,
            'minimum_payment_pct' => 0.05,
        ]);

        $e = RegisterCreditExpense::execute($user->id, $card->id, 1000);
        $e->forceFill(['occurred_at' => '2026-04-20'])->save(); // último ciclo cerrado

        $report = (new CreditCardsReport($user->id))->generate();

        $this->assertEqualsWithDelta(50, $report['cards'][0]['minimum_payment_estimated'], 0.01);
    }

    public function test_card_with_null_closing_day_returns_null_cycles_and_dates(): void
    {
        $user = $this->createUserWithBolsa();
        Account::factory()->credit()->for($user)->create([
            'closing_day' => null,
            'payment_day' => null,
            'minimum_payment_pct' => null,
        ]);

        $report = (new CreditCardsReport($user->id))->generate();

        $c = $report['cards'][0];
        $this->assertNull($c['next_closing_date']);
        $this->assertNull($c['days_to_closing']);
        $this->assertNull($c['next_payment_date']);
        $this->assertNull($c['days_to_payment']);
        $this->assertNull($c['current_cycle']);
        $this->assertNull($c['last_cycle']);
        $this->assertNull($c['minimum_payment_estimated']);
    }

    public function test_archived_cards_are_excluded(): void
    {
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create(['credit_limit' => 30000]);

        DeleteAccount::execute($user->id, $card->id);

        $report = (new CreditCardsReport($user->id))->generate();

        $this->assertCount(0, $report['cards']);
    }

    public function test_scope_is_per_user(): void
    {
        $userA = $this->createUserWithBolsa();
        $userB = $this->createUserWithBolsa();
        Account::factory()->credit()->for($userA)->create(['name' => 'Visa A']);
        Account::factory()->credit()->for($userB)->create(['name' => 'Visa B']);

        $report = (new CreditCardsReport($userA->id))->generate();

        $this->assertCount(1, $report['cards']);
        $this->assertSame('Visa A', $report['cards'][0]['name']);
    }
}
