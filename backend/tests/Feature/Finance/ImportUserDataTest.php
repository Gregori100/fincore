<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\ExportUserData;
use App\Domain\Finance\Actions\ImportUserData;
use App\Domain\Finance\Actions\RegisterIncome;
use App\Domain\Finance\Exceptions\InvalidBackupFile;
use App\Models\Account;
use App\Models\Category;
use App\Models\JournalEntry;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ImportUserDataTest extends TestCase
{
    use RefreshDatabase;

    private function sampleBackup(array $overrides = []): array
    {
        return array_merge([
            'version' => 1,
            'exported_at' => now()->toIso8601String(),
            'accounts' => [
                ['local_id' => 'acc-bolsa', 'name' => 'Bolsa', 'type' => 'cash', 'is_protected' => true],
                ['local_id' => 'acc-visa', 'name' => 'Visa', 'type' => 'credit', 'is_protected' => false, 'credit_limit' => 30000],
            ],
            'categories' => [
                ['local_id' => 'cat-cafe', 'name' => 'Café', 'applies_to' => 'expense', 'color_slug' => 'orange', 'icon_slug' => 'cake'],
            ],
            'entries' => [
                ['kind' => 'income', 'amount' => 5000, 'description' => 'sueldo', 'occurred_at' => now()->toIso8601String(), 'account_origin_local' => null, 'account_destination_local' => 'acc-bolsa', 'category_local' => null],
                ['kind' => 'credit_expense', 'amount' => 1200, 'description' => 'café', 'occurred_at' => now()->toIso8601String(), 'account_origin_local' => 'acc-visa', 'account_destination_local' => null, 'category_local' => 'cat-cafe'],
            ],
        ], $overrides);
    }

    public function test_creates_non_cash_accounts_with_new_uuid_and_user(): void
    {
        $user = $this->createUserWithBolsa();
        ImportUserData::execute($user->id, $this->sampleBackup());

        $visa = Account::where('user_id', $user->id)->where('name', 'Visa')->first();
        $this->assertNotNull($visa);
        $this->assertNotSame('acc-visa', $visa->id); // UUID regenerado
        $this->assertSame($user->id, $visa->user_id);
        $this->assertFalse((bool) $visa->is_protected);
    }

    public function test_maps_backup_cash_to_existing_bolsa_without_duplicating(): void
    {
        $user = $this->createUserWithBolsa();
        ImportUserData::execute($user->id, $this->sampleBackup());

        $cashAccounts = Account::where('user_id', $user->id)->where('type', Account::TYPE_CASH)->get();
        $this->assertCount(1, $cashAccounts);
        $this->assertTrue((bool) $cashAccounts->first()->is_protected);

        // El income al "acc-bolsa" del archivo se remapeó a la Bolsa real.
        $bolsa = $cashAccounts->first();
        $this->assertSame(1, JournalEntry::where('account_destination_id', $bolsa->id)->count());
    }

    public function test_reconciles_existing_category_by_name(): void
    {
        $user = $this->createUserWithBolsa();
        $existing = Category::create([
            'user_id' => $user->id,
            'name' => 'café', // mismo nombre, distinto case
            'applies_to' => Category::APPLIES_EXPENSE,
            'color_slug' => 'red',
            'icon_slug' => 'cake',
        ]);

        $result = ImportUserData::execute($user->id, $this->sampleBackup());

        $this->assertSame(1, $result['categories_reused']);
        $this->assertSame(0, $result['categories_created']);
        // El credit_expense quedó con la categoría existente.
        $entry = JournalEntry::where('user_id', $user->id)->where('kind', 'credit_expense')->first();
        $this->assertSame($existing->id, $entry->category_id);
    }

    public function test_creates_new_category_when_name_absent(): void
    {
        $user = $this->createUserWithBolsa();
        $result = ImportUserData::execute($user->id, $this->sampleBackup());
        $this->assertSame(1, $result['categories_created']);
    }

    public function test_skips_entry_with_invalid_amount(): void
    {
        $user = $this->createUserWithBolsa();
        $backup = $this->sampleBackup();
        $backup['entries'][] = ['kind' => 'expense', 'amount' => 0, 'occurred_at' => now()->toIso8601String(), 'account_origin_local' => 'acc-bolsa', 'account_destination_local' => null, 'category_local' => null];

        $result = ImportUserData::execute($user->id, $backup);
        $this->assertSame(1, $result['entries_skipped']);
        $this->assertSame(2, $result['entries_imported']);
    }

    public function test_skips_entry_with_unresolvable_account_reference(): void
    {
        $user = $this->createUserWithBolsa();
        $backup = $this->sampleBackup();
        $backup['entries'][] = ['kind' => 'expense', 'amount' => 100, 'occurred_at' => now()->toIso8601String(), 'account_origin_local' => 'acc-inexistente', 'account_destination_local' => null, 'category_local' => null];

        $result = ImportUserData::execute($user->id, $backup);
        $this->assertSame(1, $result['entries_skipped']);
    }

    public function test_rejects_incompatible_version(): void
    {
        $user = $this->createUserWithBolsa();
        $this->expectException(InvalidBackupFile::class);
        ImportUserData::execute($user->id, $this->sampleBackup(['version' => 99]));
    }

    public function test_rejects_malformed_structure(): void
    {
        $user = $this->createUserWithBolsa();
        $backup = $this->sampleBackup();
        unset($backup['entries']);
        $this->expectException(InvalidBackupFile::class);
        ImportUserData::execute($user->id, $backup);
    }

    public function test_rollback_on_failure_keeps_previous_data(): void
    {
        // Datos previos.
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($user->id, $bolsa->id, 9999);
        $this->assertSame(1, JournalEntry::where('user_id', $user->id)->count());

        // Backup con estructura válida pero forzamos fallo: un entry con kind válido
        // pero monto que pasa, y luego inyectamos un fallo simulando un campo que
        // rompe el insert. Usamos un occurred_at imposible de castear NO sirve (se
        // skipea). En su lugar, validamos el camino atómico con un backup gigante
        // que no falla; el rollback real se cubre confiando en DB::transaction.
        // Forzamos fallo pasando una categoría con applies_to nulo + name que choque
        // de forma que la creación lance (columna applies_to NOT NULL).
        $backup = $this->sampleBackup();
        $backup['categories'] = [
            ['local_id' => 'cat-bad', 'name' => 'X', 'applies_to' => null, 'color_slug' => null, 'icon_slug' => null],
        ];

        try {
            ImportUserData::execute($user->id, $backup);
            $this->fail('Se esperaba una excepción por categoría inválida.');
        } catch (\Throwable) {
            // esperado
        }

        // El reset NO debe haber quedado aplicado: los datos previos siguen ahí.
        $this->assertSame(1, JournalEntry::where('user_id', $user->id)->count());
        $this->assertEquals(9999, (float) JournalEntry::where('user_id', $user->id)->first()->amount);
    }
}
