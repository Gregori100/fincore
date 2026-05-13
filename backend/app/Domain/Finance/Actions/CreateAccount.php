<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\InvalidAccountType;
use App\Models\Account;

class CreateAccount
{
    public static function execute(
        string $name,
        string $type,
        array $creditMeta = [],
        ?int $userId = null,
    ): Account {
        if (! in_array($type, [Account::TYPE_CASH, Account::TYPE_DEBIT, Account::TYPE_CREDIT], true)) {
            throw new InvalidAccountType("Tipo de cuenta desconocido: {$type}");
        }

        if ($type === Account::TYPE_CASH) {
            throw new InvalidAccountType('La cuenta de efectivo (Bolsa) es única y se crea por seeder.');
        }

        $attributes = [
            'user_id' => $userId,
            'name' => $name,
            'type' => $type,
            'is_protected' => false,
        ];

        if ($type === Account::TYPE_CREDIT) {
            if (! isset($creditMeta['credit_limit'])) {
                throw new InvalidAccountType('Una cuenta de crédito requiere credit_limit.');
            }
            $attributes['credit_limit'] = $creditMeta['credit_limit'];
            $attributes['closing_day'] = $creditMeta['closing_day'] ?? null;
            $attributes['payment_day'] = $creditMeta['payment_day'] ?? null;
            $attributes['interest_rate'] = $creditMeta['interest_rate'] ?? null;
            $attributes['minimum_payment_pct'] = $creditMeta['minimum_payment_pct'] ?? null;
        }

        return Account::create($attributes);
    }
}
