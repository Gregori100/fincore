<?php

namespace App\Domain\Finance\Actions;

use App\Models\Account;
use App\Models\JournalEntry;
use App\Models\PlannedEvent;
use App\Models\PlannedEventOverride;
use Illuminate\Support\Facades\DB;

class HardResetUserData
{
    /**
     * Deja la cuenta del usuario como recién creada: borra físicamente todos los
     * movimientos, las cuentas adicionales y el plan completo. Conserva:
     *   - el usuario, su sesión y tokens (no se tocan)
     *   - la Bolsa (cuenta cash protegida), que queda vacía al perder sus movimientos
     *   - las categorías (decisión de producto: el reset es parcial)
     *
     * Borrado FÍSICO (forceDelete) deliberado: un soft delete masivo dejaría la BD
     * llena de registros con deleted_at, contradiciendo "estado recién creado".
     *
     * Orden de borrado respeta las FKs: overrides → planned_events (FK RESTRICT a
     * accounts) → journal_entries → accounts no protegidas.
     *
     * @return array{deleted_entries:int, deleted_accounts:int, deleted_planned_events:int}
     */
    public static function execute(string $userId): array
    {
        return DB::transaction(function () use ($userId) {
            $overridesDeleted = PlannedEventOverride::whereHas(
                'event',
                fn ($q) => $q->where('user_id', $userId),
            )->delete();

            $plannedEventsDeleted = PlannedEvent::where('user_id', $userId)->delete();

            // withTrashed + forceDelete para llevarse también los soft-deleteados.
            $entriesDeleted = JournalEntry::withTrashed()
                ->where('user_id', $userId)
                ->forceDelete();

            $accountsDeleted = Account::withTrashed()
                ->where('user_id', $userId)
                ->where('is_protected', false)
                ->forceDelete();

            return [
                'deleted_entries' => $entriesDeleted,
                'deleted_accounts' => $accountsDeleted,
                'deleted_planned_events' => $plannedEventsDeleted,
                'deleted_overrides' => $overridesDeleted,
            ];
        });
    }
}
