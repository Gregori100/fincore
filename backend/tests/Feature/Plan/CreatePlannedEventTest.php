<?php

namespace Tests\Feature\Plan;

use App\Domain\Finance\Exceptions\ImmutableJournalField;
use App\Domain\Finance\Exceptions\InvalidAccountType;
use App\Domain\Finance\Exceptions\InvalidCategoryAppliesTo;
use App\Domain\Finance\Plan\Actions\CreatePlannedEvent;
use App\Domain\Finance\Plan\Exceptions\InvalidRecurrence;
use App\Models\Account;
use App\Models\Category;
use App\Models\JournalEntry;
use App\Models\PlannedEvent;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

class CreatePlannedEventTest extends TestCase
{
    use RefreshDatabase;

    public function test_create_weekly_income_event(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        $event = CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 5700,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);

        $this->assertSame(JournalEntry::KIND_INCOME, $event->kind);
        $this->assertSame($bolsa->id, $event->account_destination_id);
        $this->assertNull($event->account_origin_id);
    }

    public function test_create_monthly_expense_event(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        $event = CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_EXPENSE,
            'amount' => 8000,
            'account_origin_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_MONTHLY,
            'recurrence_day' => 1,
            'start_date' => Carbon::today()->toDateString(),
        ]);

        $this->assertSame(PlannedEvent::RECURRENCE_MONTHLY, $event->recurrence_type);
        $this->assertSame(1, $event->recurrence_day);
    }

    public function test_create_one_off_credit_expense(): void
    {
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create();

        $event = CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_CREDIT_EXPENSE,
            'amount' => 4200,
            'account_origin_id' => $card->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_ONE_OFF,
            'start_date' => Carbon::today()->addDays(10)->toDateString(),
        ]);

        $this->assertSame(PlannedEvent::RECURRENCE_ONE_OFF, $event->recurrence_type);
        $this->assertNull($event->recurrence_day);
    }

    public function test_create_debt_payment_weekly(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $card = Account::factory()->credit()->for($user)->create();

        $event = CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_DEBT_PAYMENT,
            'amount' => 3000,
            'account_origin_id' => $bolsa->id,
            'account_destination_id' => $card->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);

        $this->assertSame(JournalEntry::KIND_DEBT_PAYMENT, $event->kind);
    }

    public function test_rejects_invalid_kind(): void
    {
        $user = $this->createUserWithBolsa();

        $this->expectException(InvalidRecurrence::class);

        CreatePlannedEvent::execute($user->id, [
            'kind' => 'transfer',
            'amount' => 100,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);
    }

    public function test_rejects_account_kind_mismatch(): void
    {
        $user = $this->createUserWithBolsa();
        $card = Account::factory()->credit()->for($user)->create();

        $this->expectException(InvalidAccountType::class);

        // expense apuntando a tarjeta de crédito
        CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_EXPENSE,
            'amount' => 100,
            'account_origin_id' => $card->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);
    }

    public function test_rejects_zero_amount(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        $this->expectException(ImmutableJournalField::class);

        CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 0,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);
    }

    public function test_rejects_start_after_end(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        $this->expectException(InvalidRecurrence::class);

        CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 100,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->addDays(30)->toDateString(),
            'end_date' => Carbon::today()->addDays(20)->toDateString(),
        ]);
    }

    public function test_rejects_weekly_day_out_of_range(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        $this->expectException(InvalidRecurrence::class);

        CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 100,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 7,
            'start_date' => Carbon::today()->toDateString(),
        ]);
    }

    public function test_rejects_account_of_other_user(): void
    {
        $userA = $this->createUserWithBolsa();
        $userB = $this->createUserWithBolsa();
        $bolsaB = $userB->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        $this->expectException(InvalidAccountType::class);

        CreatePlannedEvent::execute($userA->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 100,
            'account_destination_id' => $bolsaB->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);
    }

    public function test_rejects_category_incompatible_with_kind(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $incomeCategory = Category::create([
            'user_id' => $user->id,
            'name' => 'Salario X',
            'applies_to' => Category::APPLIES_INCOME,
            'color_slug' => 'green',
            'icon_slug' => 'briefcase',
        ]);

        $this->expectException(InvalidCategoryAppliesTo::class);

        CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_EXPENSE,
            'amount' => 100,
            'account_origin_id' => $bolsa->id,
            'category_id' => $incomeCategory->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);
    }

    public function test_rejects_category_on_debt_payment(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        $card = Account::factory()->credit()->for($user)->create();
        $cat = Category::create([
            'user_id' => $user->id,
            'name' => 'Cualquiera',
            'applies_to' => Category::APPLIES_BOTH,
            'color_slug' => 'indigo',
            'icon_slug' => 'credit-card',
        ]);

        $this->expectException(InvalidCategoryAppliesTo::class);

        CreatePlannedEvent::execute($user->id, [
            'kind' => JournalEntry::KIND_DEBT_PAYMENT,
            'amount' => 100,
            'account_origin_id' => $bolsa->id,
            'account_destination_id' => $card->id,
            'category_id' => $cat->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);
    }
}
