<?php

namespace Tests\Feature\Http;

use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Plan\Actions\CreatePlannedEvent;
use App\Domain\Finance\Plan\Actions\CreatePlannedEventOverride;
use App\Models\Account;
use App\Models\JournalEntry;
use App\Models\PlannedEvent;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PlanApiTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = $this->createUserWithBolsa();
        $this->user->markEmailAsVerified();
        Sanctum::actingAs($this->user);
    }

    private function bolsa(): Account
    {
        return $this->user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
    }

    public function test_list_events_returns_only_user_events(): void
    {
        $bolsa = $this->bolsa();
        CreatePlannedEvent::execute($this->user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 1000,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);

        $other = $this->createUserWithBolsa();
        $otherBolsa = $other->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        CreatePlannedEvent::execute($other->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 9999,
            'account_destination_id' => $otherBolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);

        $this->getJson('/api/finance/plan/events')
            ->assertOk()
            ->assertJsonCount(1, 'events');
    }

    public function test_create_event_via_api(): void
    {
        $bolsa = $this->bolsa();

        $this->postJson('/api/finance/plan/events', [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 5700,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ])
            ->assertCreated()
            ->assertJsonPath('event.kind', 'income')
            ->assertJsonPath('event.recurrence_type', 'weekly');
    }

    public function test_create_event_invalid_recurrence(): void
    {
        $bolsa = $this->bolsa();
        $this->postJson('/api/finance/plan/events', [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 100,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => 'weekly',
            'recurrence_day' => 10,
            'start_date' => Carbon::today()->toDateString(),
        ])
            ->assertStatus(422)
            ->assertJsonPath('code', 'invalid_recurrence');
    }

    public function test_create_event_invalid_account_type(): void
    {
        $card = Account::factory()->credit()->for($this->user)->create();
        $this->postJson('/api/finance/plan/events', [
            'kind' => JournalEntry::KIND_EXPENSE,
            'amount' => 100,
            'account_origin_id' => $card->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ])
            ->assertStatus(422)
            ->assertJsonPath('code', 'invalid_account_type');
    }

    public function test_patch_event(): void
    {
        $bolsa = $this->bolsa();
        $event = CreatePlannedEvent::execute($this->user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 1000,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);

        $this->patchJson("/api/finance/plan/events/{$event->id}", ['amount' => 2000])
            ->assertOk()
            ->assertJsonPath('event.amount', '2000.00');
    }

    public function test_patch_recurrence_removes_orphan_overrides(): void
    {
        $bolsa = $this->bolsa();
        $event = CreatePlannedEvent::execute($this->user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 1000,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);
        $first = $event->occurrencesBetween(Carbon::today(), Carbon::today()->addWeeks(2))->first();
        CreatePlannedEventOverride::execute($this->user->id, $event->id, [
            'occurrence_date' => $first->toDateString(),
            'amount' => 999,
        ]);

        $this->patchJson("/api/finance/plan/events/{$event->id}", ['recurrence_day' => 6])
            ->assertOk()
            ->assertJsonPath('removed_overrides', 1);
    }

    public function test_delete_event_cascades(): void
    {
        $bolsa = $this->bolsa();
        $event = CreatePlannedEvent::execute($this->user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 1000,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);

        $this->deleteJson("/api/finance/plan/events/{$event->id}")
            ->assertOk();
        $this->assertNull($event->fresh());
    }

    public function test_create_override_on_one_off_fails(): void
    {
        $bolsa = $this->bolsa();
        $event = CreatePlannedEvent::execute($this->user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 1000,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_ONE_OFF,
            'start_date' => Carbon::today()->addDays(5)->toDateString(),
        ]);

        $this->postJson("/api/finance/plan/events/{$event->id}/overrides", [
            'occurrence_date' => Carbon::today()->addDays(5)->toDateString(),
            'amount' => 500,
        ])
            ->assertStatus(422)
            ->assertJsonPath('code', 'invalid_recurrence');
    }

    public function test_create_override_on_non_occurrence(): void
    {
        $bolsa = $this->bolsa();
        $event = CreatePlannedEvent::execute($this->user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 1000,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);
        // Cualquier martes desde hoy.
        $tuesday = Carbon::today()->next(Carbon::TUESDAY);

        $this->postJson("/api/finance/plan/events/{$event->id}/overrides", [
            'occurrence_date' => $tuesday->toDateString(),
            'amount' => 500,
        ])
            ->assertStatus(422)
            ->assertJsonPath('code', 'override_on_non_occurrence');
    }

    public function test_projection_returns_shape(): void
    {
        $bolsa = $this->bolsa();
        RegisterIncome::execute($this->user->id, $bolsa->id, 1000);

        $this->getJson('/api/finance/plan/projection')
            ->assertOk()
            ->assertJsonStructure(['horizon' => ['from', 'to'], 'accounts', 'series', 'events']);
    }

    public function test_projection_scoped_by_user(): void
    {
        $other = $this->createUserWithBolsa();
        $otherBolsa = $other->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        CreatePlannedEvent::execute($other->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 9999,
            'account_destination_id' => $otherBolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);

        $this->getJson('/api/finance/plan/projection')
            ->assertOk()
            ->assertJsonPath('events', []);
    }

    public function test_endpoints_require_authentication(): void
    {
        Sanctum::actingAs(User::factory()->unverified()->create());
        // sin email verificado, debe rebotar el middleware verified.
        $this->getJson('/api/finance/plan/events')->assertStatus(403);
    }

    public function test_clear_events_removes_all_user_events(): void
    {
        $bolsa = $this->bolsa();
        CreatePlannedEvent::execute($this->user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 1000,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);
        CreatePlannedEvent::execute($this->user->id, [
            'kind' => JournalEntry::KIND_EXPENSE,
            'amount' => 500,
            'account_origin_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_ONE_OFF,
            'start_date' => Carbon::today()->addDays(5)->toDateString(),
        ]);

        // Otro usuario no se ve afectado.
        $other = $this->createUserWithBolsa();
        $otherBolsa = $other->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        CreatePlannedEvent::execute($other->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 999,
            'account_destination_id' => $otherBolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);

        $this->deleteJson('/api/finance/plan/events')
            ->assertOk()
            ->assertJsonPath('deleted', 2);

        $this->assertSame(0, PlannedEvent::where('user_id', $this->user->id)->count());
        $this->assertSame(1, PlannedEvent::where('user_id', $other->id)->count());
    }

    public function test_validation_rejects_far_future_start_date(): void
    {
        $bolsa = $this->bolsa();
        $this->postJson('/api/finance/plan/events', [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 100,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_ONE_OFF,
            'start_date' => Carbon::today()->addYears(6)->toDateString(),
        ])
            ->assertStatus(422)
            ->assertJsonPath('code', 'invalid_recurrence');
    }
}
