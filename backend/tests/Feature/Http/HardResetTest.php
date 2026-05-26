<?php

namespace Tests\Feature\Http;

use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Plan\Actions\CreatePlannedEvent;
use App\Models\Account;
use App\Models\Category;
use App\Models\JournalEntry;
use App\Models\PlannedEvent;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class HardResetTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        $this->user = $this->createUserWithBolsa();
        $this->user->markEmailAsVerified();
        $this->user->forceFill(['password' => bcrypt('secret-pass')])->save();
        Sanctum::actingAs($this->user);
    }

    private function bolsa(): Account
    {
        return $this->user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
    }

    private function seedData(): void
    {
        $bolsa = $this->bolsa();
        $card = Account::factory()->credit()->for($this->user)->create();
        RegisterIncome::execute($this->user->id, $bolsa->id, 5000);
        RegisterCreditExpense::execute($this->user->id, $card->id, 1000);
        CreatePlannedEvent::execute($this->user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 5000,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);
        Category::create([
            'user_id' => $this->user->id,
            'name' => 'Mi categoría custom',
            'applies_to' => Category::APPLIES_EXPENSE,
            'color_slug' => 'orange',
            'icon_slug' => 'cake',
        ]);
    }

    public function test_hard_reset_clears_data_but_keeps_bolsa_and_categories(): void
    {
        $this->seedData();
        $categoriesBefore = Category::where('user_id', $this->user->id)->count();
        $this->assertGreaterThan(0, $categoriesBefore);

        $this->postJson('/api/finance/reset', ['password' => 'secret-pass'])
            ->assertOk()
            ->assertJsonPath('deleted_entries', 2)
            ->assertJsonPath('deleted_accounts', 1);

        // Bolsa sobrevive y queda vacía.
        $accounts = Account::where('user_id', $this->user->id)->get();
        $this->assertCount(1, $accounts);
        $this->assertTrue($accounts->first()->is_protected);
        $this->assertSame(0, JournalEntry::where('user_id', $this->user->id)->count());
        $this->assertSame(0, PlannedEvent::where('user_id', $this->user->id)->count());

        // Categorías intactas (decisión: reset parcial).
        $this->assertSame($categoriesBefore, Category::where('user_id', $this->user->id)->count());
    }

    public function test_hard_reset_force_deletes_soft_deleted_records(): void
    {
        $bolsa = $this->bolsa();
        $entry = RegisterIncome::execute($this->user->id, $bolsa->id, 1000);
        $entry->delete(); // soft delete

        $this->postJson('/api/finance/reset', ['password' => 'secret-pass'])->assertOk();

        $this->assertSame(0, JournalEntry::withTrashed()->where('user_id', $this->user->id)->count());
    }

    public function test_hard_reset_requires_correct_password(): void
    {
        $this->seedData();

        $this->postJson('/api/finance/reset', ['password' => 'wrong'])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['password']);

        // Nada se borró.
        $this->assertSame(2, JournalEntry::where('user_id', $this->user->id)->count());
    }

    public function test_hard_reset_requires_password_field(): void
    {
        $this->postJson('/api/finance/reset', [])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['password']);
    }

    public function test_hard_reset_scoped_to_current_user(): void
    {
        $this->seedData();

        $other = $this->createUserWithBolsa();
        $otherBolsa = $other->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($other->id, $otherBolsa->id, 3000);

        $this->postJson('/api/finance/reset', ['password' => 'secret-pass'])->assertOk();

        // El otro usuario conserva sus datos.
        $this->assertSame(1, JournalEntry::where('user_id', $other->id)->count());
    }
}
