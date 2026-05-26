<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\InvalidBackupFile;
use App\Models\Account;
use App\Models\Category;
use App\Models\JournalEntry;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class ImportUserData
{
    private const KINDS = [
        JournalEntry::KIND_INCOME,
        JournalEntry::KIND_EXPENSE,
        JournalEntry::KIND_CREDIT_EXPENSE,
        JournalEntry::KIND_DEBT_PAYMENT,
        JournalEntry::KIND_TRANSFER,
    ];

    /**
     * Reemplazo total: valida el respaldo, vacía la cuenta (hard reset full) y
     * restaura el contenido del archivo, regenerando UUIDs y remapeando FKs.
     *
     * Toda la operación corre en UNA transacción. `HardResetUserData` abre su
     * propia transacción interna, que Laravel anida con savepoint; si el restore
     * lanza después del reset, el rollback de esta transacción externa revierte
     * también el borrado, dejando la cuenta como estaba antes del import.
     *
     * @return array{accounts_created:int, categories_created:int, categories_reused:int, entries_imported:int, entries_skipped:int}
     */
    public static function execute(string $userId, array $backup): array
    {
        self::validateStructure($backup);

        return DB::transaction(function () use ($userId, $backup) {
            HardResetUserData::execute($userId, HardResetUserData::MODE_FULL);

            $accountMap = self::restoreAccounts($userId, $backup['accounts'], $accountsCreated);
            $categoryMap = self::restoreCategories($userId, $backup['categories'], $categoriesCreated, $categoriesReused);
            [$entriesImported, $entriesSkipped] = self::restoreEntries($userId, $backup['entries'], $accountMap, $categoryMap);

            return [
                'accounts_created' => $accountsCreated,
                'categories_created' => $categoriesCreated,
                'categories_reused' => $categoriesReused,
                'entries_imported' => $entriesImported,
                'entries_skipped' => $entriesSkipped,
            ];
        });
    }

    private static function validateStructure(array $backup): void
    {
        if (($backup['version'] ?? null) !== ExportUserData::VERSION) {
            throw new InvalidBackupFile('Versión de respaldo incompatible.');
        }
        foreach (['accounts', 'categories', 'entries'] as $key) {
            if (! array_key_exists($key, $backup) || ! is_array($backup[$key])) {
                throw new InvalidBackupFile("El respaldo no tiene la estructura esperada (falta '{$key}').");
            }
        }
    }

    /**
     * @return array<string,string> mapa local_id → id real de cuenta
     */
    private static function restoreAccounts(string $userId, array $accounts, ?int &$created): array
    {
        $created = 0;
        $map = [];

        // La Bolsa la conserva el reset; las cuentas cash/protegidas del archivo
        // se mapean a ella en lugar de crear una segunda.
        $bolsa = Account::where('user_id', $userId)
            ->where('is_protected', true)
            ->where('type', Account::TYPE_CASH)
            ->first();

        foreach ($accounts as $a) {
            $localId = $a['local_id'] ?? null;
            if ($localId === null) {
                continue;
            }

            $isCashLike = ($a['type'] ?? null) === Account::TYPE_CASH || ! empty($a['is_protected']);
            if ($isCashLike && $bolsa !== null) {
                $map[$localId] = $bolsa->id;
                continue;
            }

            $new = Account::create([
                'user_id' => $userId,
                'name' => $a['name'] ?? 'Cuenta importada',
                'type' => $a['type'] ?? Account::TYPE_DEBIT,
                'is_protected' => false,
                'description' => $a['description'] ?? null,
                'credit_limit' => $a['credit_limit'] ?? null,
                'closing_day' => $a['closing_day'] ?? null,
                'payment_day' => $a['payment_day'] ?? null,
                'interest_rate' => $a['interest_rate'] ?? null,
                'minimum_payment_pct' => $a['minimum_payment_pct'] ?? null,
            ]);
            $map[$localId] = $new->id;
            $created++;
        }

        return $map;
    }

    /**
     * @return array<string,string> mapa local_id → id real de categoría
     */
    private static function restoreCategories(string $userId, array $categories, ?int &$created, ?int &$reused): array
    {
        $created = 0;
        $reused = 0;
        $map = [];

        $existing = Category::where('user_id', $userId)->get();

        foreach ($categories as $c) {
            $localId = $c['local_id'] ?? null;
            $name = $c['name'] ?? null;
            if ($localId === null || $name === null) {
                continue;
            }

            $match = $existing->first(
                fn (Category $e) => mb_strtolower(trim($e->name)) === mb_strtolower(trim($name)),
            );

            if ($match !== null) {
                $map[$localId] = $match->id;
                $reused++;
                continue;
            }

            $new = Category::create([
                'user_id' => $userId,
                'name' => $name,
                'applies_to' => $c['applies_to'] ?? Category::APPLIES_BOTH,
                'color_slug' => $c['color_slug'] ?? null,
                'icon_slug' => $c['icon_slug'] ?? null,
                'monthly_limit' => $c['monthly_limit'] ?? null,
            ]);
            $existing->push($new); // dedup intra-archivo
            $map[$localId] = $new->id;
            $created++;
        }

        return $map;
    }

    /**
     * @return array{0:int,1:int} [importados, omitidos]
     */
    private static function restoreEntries(string $userId, array $entries, array $accountMap, array $categoryMap): array
    {
        $imported = 0;
        $skipped = 0;

        foreach ($entries as $e) {
            $kind = $e['kind'] ?? null;
            $amount = $e['amount'] ?? null;

            if (! in_array($kind, self::KINDS, true) || ! is_numeric($amount) || (float) $amount <= 0) {
                $skipped++;
                continue;
            }

            try {
                $occurredAt = Carbon::parse($e['occurred_at'] ?? null);
            } catch (\Exception) {
                $skipped++;
                continue;
            }

            // Resolver cuentas. Una referencia no-null que no resuelve invalida la fila.
            $originId = null;
            if (($e['account_origin_local'] ?? null) !== null) {
                if (! isset($accountMap[$e['account_origin_local']])) {
                    $skipped++;
                    continue;
                }
                $originId = $accountMap[$e['account_origin_local']];
            }

            $destinationId = null;
            if (($e['account_destination_local'] ?? null) !== null) {
                if (! isset($accountMap[$e['account_destination_local']])) {
                    $skipped++;
                    continue;
                }
                $destinationId = $accountMap[$e['account_destination_local']];
            }

            // La categoría es opcional: si no resuelve, el movimiento queda sin categoría.
            $categoryId = null;
            if (($e['category_local'] ?? null) !== null && isset($categoryMap[$e['category_local']])) {
                $categoryId = $categoryMap[$e['category_local']];
            }

            JournalEntry::create([
                'user_id' => $userId,
                'kind' => $kind,
                'amount' => (float) $amount,
                'account_origin_id' => $originId,
                'account_destination_id' => $destinationId,
                'category_id' => $categoryId,
                'description' => $e['description'] ?? null,
                'occurred_at' => $occurredAt,
            ]);
            $imported++;
        }

        return [$imported, $skipped];
    }
}
