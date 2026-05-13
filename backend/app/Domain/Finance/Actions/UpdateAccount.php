<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\ProtectedAccount;
use App\Models\Account;

class UpdateAccount
{
    private const EDITABLE_FIELDS = [
        'name',
        'credit_limit',
        'closing_day',
        'payment_day',
        'interest_rate',
        'minimum_payment_pct',
    ];

    public static function execute(int $accountId, array $changes): Account
    {
        $account = Account::findOrFail($accountId);

        if ($account->is_protected) {
            throw new ProtectedAccount();
        }

        $update = array_intersect_key($changes, array_flip(self::EDITABLE_FIELDS));

        if ($account->type !== Account::TYPE_CREDIT) {
            foreach (['credit_limit', 'closing_day', 'payment_day', 'interest_rate', 'minimum_payment_pct'] as $creditField) {
                unset($update[$creditField]);
            }
        }

        $account->update($update);

        return $account->fresh();
    }
}
