<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\DuplicateAccountName;
use App\Domain\Finance\Exceptions\InvalidAccountType;
use App\Domain\Finance\Exceptions\InvalidCreditLimit;
use App\Domain\Finance\Exceptions\InvalidCreditMetadata;
use App\Domain\Finance\Exceptions\ProtectedAccount;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Account;

class UpdateAccount
{
    private const EDITABLE_FIELDS = [
        'name',
        'description',
        'credit_limit',
        'closing_day',
        'payment_day',
        'interest_rate',
        'minimum_payment_pct',
    ];

    private const MAX_NAME_LENGTH = 120;

    private const MAX_DESCRIPTION_LENGTH = 200;

    public static function execute(string $userId, string $accountId, array $changes): Account
    {
        $account = Account::where('id', $accountId)
            ->where('user_id', $userId)
            ->firstOrFail();

        if ($account->is_protected) {
            throw new ProtectedAccount();
        }

        $update = array_intersect_key($changes, array_flip(self::EDITABLE_FIELDS));

        // Normalizar el nombre si viene en el update.
        if (array_key_exists('name', $update)) {
            $update['name'] = trim((string) $update['name']);
            if ($update['name'] === '') {
                throw new InvalidAccountType('El nombre es obligatorio.');
            }
            if (mb_strlen($update['name']) > self::MAX_NAME_LENGTH) {
                throw new InvalidAccountType('El nombre no puede exceder '.self::MAX_NAME_LENGTH.' caracteres.');
            }

            // Unicidad case-insensitive (excluyendo la propia cuenta).
            $duplicated = Account::withTrashed()
                ->where('user_id', $userId)
                ->where('id', '!=', $accountId)
                ->whereRaw('LOWER(name) = ?', [mb_strtolower($update['name'])])
                ->exists();
            if ($duplicated) {
                throw new DuplicateAccountName();
            }
        }

        // Normalizar description. null o cadena vacía borran el campo.
        if (array_key_exists('description', $update)) {
            if ($update['description'] === null) {
                $update['description'] = null;
            } else {
                $trimmed = trim((string) $update['description']);
                if (mb_strlen($trimmed) > self::MAX_DESCRIPTION_LENGTH) {
                    throw new InvalidAccountType('La descripción no puede exceder '.self::MAX_DESCRIPTION_LENGTH.' caracteres.');
                }
                $update['description'] = $trimmed !== '' ? $trimmed : null;
            }
        }

        if ($account->type !== Account::TYPE_CREDIT) {
            foreach (['credit_limit', 'closing_day', 'payment_day', 'interest_rate', 'minimum_payment_pct'] as $creditField) {
                unset($update[$creditField]);
            }
        }

        // Validaciones específicas de cuenta de crédito.
        if ($account->isCredit()) {
            if (array_key_exists('credit_limit', $update)) {
                if ($update['credit_limit'] === null) {
                    throw new InvalidCreditLimit('No puedes quitar el límite de una cuenta de crédito.');
                }

                $state = new FinancialStateService($userId);
                $currentDebt = $state->getAccountBalance($account->id);
                if ((float) $update['credit_limit'] < $currentDebt) {
                    throw new InvalidCreditLimit();
                }
            }

            // closing_day y payment_day no pueden quedar iguales tras el update.
            // Comparamos los valores efectivos (el nuevo si viene, sino el existente).
            $closing = array_key_exists('closing_day', $update)
                ? $update['closing_day']
                : $account->closing_day;
            $payment = array_key_exists('payment_day', $update)
                ? $update['payment_day']
                : $account->payment_day;
            if (
                $closing !== null && $payment !== null
                && (int) $closing === (int) $payment
            ) {
                throw new InvalidCreditMetadata();
            }
        }

        $account->update($update);

        return $account->fresh();
    }
}
