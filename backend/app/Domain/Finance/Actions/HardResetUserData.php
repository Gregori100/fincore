<?php

namespace App\Domain\Finance\Actions;

use App\Models\Account;
use App\Models\JournalEntry;
use App\Models\PlannedEvent;
use App\Models\PlannedEventOverride;
use Illuminate\Support\Facades\DB;

class HardResetUserData
{
    /** Borra movimientos, cuentas adicionales y el plan completo. Deja la cuenta como recién creada. */
    public const MODE_FULL = 'full';

    /** Borra sólo los movimientos. Conserva cuentas (quedan en saldo 0), categorías y plan. */
    public const MODE_MOVEMENTS = 'movements';

    public const MODES = [self::MODE_FULL, self::MODE_MOVEMENTS];

    /**
     * Borrado FÍSICO (forceDelete) deliberado: un soft delete masivo dejaría la BD
     * llena de registros con deleted_at, contradiciendo "estado limpio". Siempre
     * conserva el usuario, su sesión/tokens y las categorías.
     *
     * - MODE_FULL: borra overrides → planned_events (FK RESTRICT a accounts) →
     *   journal_entries → cuentas no protegidas. La Bolsa sobrevive vacía.
     * - MODE_MOVEMENTS: borra sólo journal_entries. Cuentas, categorías y plan
     *   intactos; las cuentas quedan en saldo 0 al perder sus movimientos.
     *
     * @return array{deleted_entries:int, deleted_accounts:int, deleted_planned_events:int, deleted_overrides:int}
     */
    public static function execute(string $userId, string $mode = self::MODE_FULL): array
    {
        return DB::transaction(function () use ($userId, $mode) {
            $overridesDeleted = 0;
            $plannedEventsDeleted = 0;
            $accountsDeleted = 0;

            if ($mode === self::MODE_FULL) {
                $overridesDeleted = PlannedEventOverride::whereHas(
                    'event',
                    fn ($q) => $q->where('user_id', $userId),
                )->delete();

                $plannedEventsDeleted = PlannedEvent::where('user_id', $userId)->delete();
            }

            // withTrashed + forceDelete para llevarse también los soft-deleteados.
            $entriesDeleted = JournalEntry::withTrashed()
                ->where('user_id', $userId)
                ->forceDelete();

            if ($mode === self::MODE_FULL) {
                $accountsDeleted = Account::withTrashed()
                    ->where('user_id', $userId)
                    ->where('is_protected', false)
                    ->forceDelete();
            }

            return [
                'deleted_entries' => $entriesDeleted,
                'deleted_accounts' => $accountsDeleted,
                'deleted_planned_events' => $plannedEventsDeleted,
                'deleted_overrides' => $overridesDeleted,
            ];
        });
    }
}
