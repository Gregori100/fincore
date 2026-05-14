<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\AccountNotEmpty;
use App\Domain\Finance\Exceptions\ProtectedAccount;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Account;
use Illuminate\Support\Facades\DB;

/**
 * "Eliminar" una cuenta en FinCore es realmente un soft delete: el modelo
 * Account tiene SoftDeletes trait, así que delete() solo setea deleted_at.
 * Esto preserva la historia de pólizas: /entries sigue mostrando los
 * movimientos donde origin/destination apuntaban a la cuenta archivada.
 *
 * Solo permitimos archivar cuentas vacías:
 *   - cash/debit: balance == 0 (transfiere o gasta todo antes)
 *   - credit:     balance == 0 (paga toda la deuda antes)
 */
class DeleteAccount
{
    // Tolerancia para comparar balance con cero (evita falsos positivos por
    // imprecisión de float).
    private const ZERO_TOLERANCE = 0.005;

    public static function execute(int $userId, int $accountId): void
    {
        $account = Account::where('id', $accountId)
            ->where('user_id', $userId)
            ->firstOrFail();

        if ($account->is_protected) {
            throw new ProtectedAccount();
        }

        $state = new FinancialStateService($userId);
        $balance = $state->getAccountBalance($account->id);

        if (abs($balance) > self::ZERO_TOLERANCE) {
            $message = $account->isCredit()
                ? 'Esta tarjeta tiene una deuda pendiente. Págala completamente antes de archivar.'
                : 'Esta cuenta tiene saldo. Transfiérelo o gástalo todo antes de archivar.';
            throw new AccountNotEmpty($message);
        }

        DB::transaction(fn () => $account->delete());
    }
}
