<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\InsufficientFunds;
use App\Domain\Finance\Exceptions\InvalidAccountType;
use App\Domain\Finance\Exceptions\OverpayDebt;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Account;
use App\Models\JournalEntry;
use Illuminate\Support\Facades\DB;

class PayCreditAccount
{
    public static function execute(
        int $userId,
        int $originAccountId,
        int $creditAccountId,
        float $amount,
        ?string $description = null,
    ): JournalEntry {
        $origin = Account::where('id', $originAccountId)
            ->where('user_id', $userId)
            ->firstOrFail();

        $credit = Account::where('id', $creditAccountId)
            ->where('user_id', $userId)
            ->firstOrFail();

        if (! $origin->isCashLike()) {
            throw new InvalidAccountType('El pago debe salir de una cuenta cash o debit.');
        }

        if (! $credit->isCredit()) {
            throw new InvalidAccountType('El destino del pago debe ser una cuenta de crédito.');
        }

        $state = new FinancialStateService($userId);

        if ($amount > $state->getAccountBalance($origin->id)) {
            throw new InsufficientFunds();
        }

        if ($amount > $state->getAccountBalance($credit->id)) {
            throw new OverpayDebt();
        }

        return DB::transaction(fn () => JournalEntry::create([
            'user_id' => $userId,
            'kind' => JournalEntry::KIND_DEBT_PAYMENT,
            'amount' => $amount,
            'account_origin_id' => $origin->id,
            'account_destination_id' => $credit->id,
            'description' => $description,
            'occurred_at' => now(),
        ]));
    }
}
