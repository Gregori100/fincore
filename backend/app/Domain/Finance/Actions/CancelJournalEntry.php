<?php

namespace App\Domain\Finance\Actions;

use App\Models\JournalEntry;

class CancelJournalEntry
{
    /**
     * Cancela (soft delete) un movimiento del usuario. El balance se
     * autocorrige porque `FinancialStateService::getAccountBalance` y todas
     * las queries que tocan JournalEntry respetan el scope global de
     * SoftDeletes (los cancelados ya no se suman ni se restan).
     *
     * Permite dejar saldos negativos: cancelar un ingreso ya gastado, por
     * ejemplo, deja la cuenta en negativo y el frontend muestra el warning.
     * Es responsabilidad del usuario corregir manualmente si quiere.
     *
     * No hay reactivación: una vez cancelado, el movimiento es histórico.
     */
    public static function execute(string $userId, string $entryId): void
    {
        $entry = JournalEntry::where('id', $entryId)
            ->where('user_id', $userId)
            ->firstOrFail();

        $entry->delete();
    }
}
