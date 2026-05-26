<?php

namespace Tests\Feature\Http;

use App\Domain\Finance\Actions\RegisterCreditExpense;
use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Actions\RegisterTransfer;
use App\Domain\Finance\Plan\Actions\CreatePlannedEvent;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Account;
use App\Models\JournalEntry;
use App\Models\PlannedEvent;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class BackupTest extends TestCase
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

    private function seedRichDataset(): void
    {
        $bolsa = $this->bolsa();
        $banamex = Account::factory()->debit()->for($this->user)->create(['name' => 'Banamex']);
        $visa = Account::factory()->credit()->for($this->user)->create(['name' => 'Visa', 'credit_limit' => 30000]);

        RegisterIncome::execute($this->user->id, $bolsa->id, 20000);
        RegisterExpense::execute($this->user->id, $bolsa->id, 1500);
        RegisterTransfer::execute($this->user->id, $bolsa->id, $banamex->id, 5000);
        RegisterCreditExpense::execute($this->user->id, $visa->id, 3000);
        RegisterIncome::execute($this->user->id, $banamex->id, 800);
    }

    public function test_export_returns_expected_shape(): void
    {
        $this->seedRichDataset();
        $this->getJson('/api/finance/backup/export')
            ->assertOk()
            ->assertJsonPath('version', 1)
            ->assertJsonStructure(['version', 'exported_at', 'accounts', 'categories', 'entries']);
    }

    public function test_export_excludes_soft_deleted(): void
    {
        $bolsa = $this->bolsa();
        $entry = RegisterIncome::execute($this->user->id, $bolsa->id, 1000);
        $entry->delete(); // soft delete

        $data = $this->getJson('/api/finance/backup/export')->json();
        $this->assertCount(0, $data['entries']);
    }

    public function test_export_excludes_plan(): void
    {
        $bolsa = $this->bolsa();
        CreatePlannedEvent::execute($this->user->id, [
            'kind' => JournalEntry::KIND_INCOME,
            'amount' => 5000,
            'account_destination_id' => $bolsa->id,
            'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
            'recurrence_day' => 4,
            'start_date' => Carbon::today()->toDateString(),
        ]);

        $data = $this->getJson('/api/finance/backup/export')->json();
        $this->assertArrayNotHasKey('planned_events', $data);
        $this->assertArrayNotHasKey('plan', $data);
    }

    public function test_import_requires_password(): void
    {
        $this->postJson('/api/finance/backup/import', ['backup' => ['version' => 1, 'accounts' => [], 'categories' => [], 'entries' => []]])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['password']);
    }

    public function test_import_rejects_wrong_password(): void
    {
        $this->seedRichDataset();
        $this->postJson('/api/finance/backup/import', [
            'password' => 'wrong',
            'backup' => ['version' => 1, 'accounts' => [], 'categories' => [], 'entries' => []],
        ])->assertStatus(422)->assertJsonValidationErrors(['password']);

        // Nada se borró.
        $this->assertGreaterThan(0, JournalEntry::where('user_id', $this->user->id)->count());
    }

    public function test_import_rejects_invalid_version(): void
    {
        $this->postJson('/api/finance/backup/import', [
            'password' => 'secret-pass',
            'backup' => ['version' => 99, 'accounts' => [], 'categories' => [], 'entries' => []],
        ])
            ->assertStatus(422)
            ->assertJsonPath('code', 'invalid_backup_file');
    }

    public function test_full_cycle_preserves_balances(): void
    {
        $this->seedRichDataset();

        $state = new FinancialStateService($this->user->id);
        $boBefore = $state->getBO();
        $deBefore = $state->getDE();
        $crBefore = $state->getCR();

        // Export.
        $backup = $this->getJson('/api/finance/backup/export')->json();

        // Reset + import (replace).
        $this->postJson('/api/finance/backup/import', [
            'password' => 'secret-pass',
            'backup' => $backup,
        ])->assertOk();

        $stateAfter = new FinancialStateService($this->user->id);
        $this->assertEqualsWithDelta($boBefore, $stateAfter->getBO(), 0.001);
        $this->assertEqualsWithDelta($deBefore, $stateAfter->getDE(), 0.001);
        $this->assertEqualsWithDelta($crBefore, $stateAfter->getCR(), 0.001);
    }

    public function test_import_regenerates_ids_and_does_not_duplicate_bolsa(): void
    {
        $this->seedRichDataset();
        $backup = $this->getJson('/api/finance/backup/export')->json();
        $originalAccountIds = collect($backup['accounts'])->pluck('local_id')->all();

        $this->postJson('/api/finance/backup/import', [
            'password' => 'secret-pass',
            'backup' => $backup,
        ])->assertOk();

        // Una sola Bolsa.
        $this->assertSame(1, Account::where('user_id', $this->user->id)->where('type', Account::TYPE_CASH)->count());

        // Ningún id del archivo persiste como id real (salvo la Bolsa, que es la
        // existente; verificamos que las cuentas nuevas tienen ids distintos).
        $currentIds = Account::where('user_id', $this->user->id)->pluck('id')->all();
        $nonBolsaOriginal = collect($backup['accounts'])->where('type', '!=', 'cash')->pluck('local_id')->all();
        foreach ($nonBolsaOriginal as $oldId) {
            $this->assertNotContains($oldId, $currentIds);
        }
    }

    public function test_import_into_another_account(): void
    {
        $this->seedRichDataset();
        $backup = $this->getJson('/api/finance/backup/export')->json();

        // Segundo usuario, cuenta limpia.
        $userB = $this->createUserWithBolsa();
        $userB->markEmailAsVerified();
        $userB->forceFill(['password' => bcrypt('pass-b')])->save();
        Sanctum::actingAs($userB);

        $this->postJson('/api/finance/backup/import', [
            'password' => 'pass-b',
            'backup' => $backup,
        ])->assertOk();

        // userB quedó con las cuentas del respaldo.
        $this->assertGreaterThan(1, Account::where('user_id', $userB->id)->count());
        // userA intacto.
        $this->assertGreaterThan(0, JournalEntry::where('user_id', $this->user->id)->count());
    }

    public function test_import_returns_summary(): void
    {
        $this->seedRichDataset();
        $backup = $this->getJson('/api/finance/backup/export')->json();

        $this->postJson('/api/finance/backup/import', [
            'password' => 'secret-pass',
            'backup' => $backup,
        ])
            ->assertOk()
            ->assertJsonStructure(['message', 'accounts_created', 'categories_created', 'categories_reused', 'entries_imported', 'entries_skipped']);
    }

    public function test_endpoints_require_verified(): void
    {
        Sanctum::actingAs(User::factory()->unverified()->create());
        $this->getJson('/api/finance/backup/export')->assertStatus(403);
    }
}
