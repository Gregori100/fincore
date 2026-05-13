<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\InsufficientFunds;
use App\Domain\Finance\Exceptions\InvalidAccountType;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Account;
use App\Models\JournalEntry;
use Illuminate\Support\Facades\DB;

class RegisterTransfer
{
    public static function execute(
        int $originAccountId,
        int $destinationAccountId,
        float $amount,
        ?string $description = null,
    ): JournalEntry {
        if ($originAccountId === $destinationAccountId) {
            throw new InvalidAccountType('La cuenta de origen y destino no pueden ser la misma.');
        }

        $origin = Account::findOrFail($originAccountId);
        $destination = Account::findOrFail($destinationAccountId);

        if (! $origin->isCashLike() || ! $destination->isCashLike()) {
            throw new InvalidAccountType('Las transferencias solo se permiten entre cuentas cash o debit. Usa pay-credit para pagar tarjetas.');
        }

        $state = new FinancialStateService();
        if ($amount > $state->getAccountBalance($origin->id)) {
            throw new InsufficientFunds();
        }

        return DB::transaction(fn () => JournalEntry::create([
            'user_id' => $origin->user_id,
            'kind' => JournalEntry::KIND_TRANSFER,
            'amount' => $amount,
            'account_origin_id' => $origin->id,
            'account_destination_id' => $destination->id,
            'description' => $description,
            'occurred_at' => now(),
        ]));
    }
}
