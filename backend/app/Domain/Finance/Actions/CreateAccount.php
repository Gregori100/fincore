<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\DuplicateAccountName;
use App\Domain\Finance\Exceptions\InvalidAccountType;
use App\Domain\Finance\Exceptions\InvalidCreditLimit;
use App\Domain\Finance\Exceptions\InvalidCreditMetadata;
use App\Models\Account;

class CreateAccount
{
    private const MAX_NAME_LENGTH = 120;

    private const MAX_DESCRIPTION_LENGTH = 200;

    public static function execute(
        string $userId,
        string $name,
        string $type,
        array $creditMeta = [],
        ?string $description = null,
    ): Account {
        $name = trim($name);

        if ($name === '') {
            throw new InvalidAccountType('El nombre es obligatorio.');
        }
        if (mb_strlen($name) > self::MAX_NAME_LENGTH) {
            throw new InvalidAccountType('El nombre no puede exceder '.self::MAX_NAME_LENGTH.' caracteres.');
        }

        if (! in_array($type, [Account::TYPE_CASH, Account::TYPE_DEBIT, Account::TYPE_CREDIT], true)) {
            throw new InvalidAccountType("Tipo de cuenta desconocido: {$type}");
        }

        if ($type === Account::TYPE_CASH) {
            throw new InvalidAccountType('La cuenta de efectivo (Bolsa) es única por usuario y se crea automáticamente al registrarse.');
        }

        // Descripción opcional. Trim + max 200; cadena vacía se persiste como null.
        $normalizedDescription = null;
        if ($description !== null) {
            $trimmed = trim($description);
            if (mb_strlen($trimmed) > self::MAX_DESCRIPTION_LENGTH) {
                throw new InvalidAccountType('La descripción no puede exceder '.self::MAX_DESCRIPTION_LENGTH.' caracteres.');
            }
            $normalizedDescription = $trimmed !== '' ? $trimmed : null;
        }

        // Unicidad case-insensitive. withTrashed() para que un nombre archivado
        // siga ocupando el slot (evita que el user "reuse" un nombre de cuenta
        // anterior y se confunda al ver entries históricas).
        $exists = Account::withTrashed()
            ->where('user_id', $userId)
            ->whereRaw('LOWER(name) = ?', [mb_strtolower($name)])
            ->exists();
        if ($exists) {
            throw new DuplicateAccountName();
        }

        $attributes = [
            'user_id' => $userId,
            'name' => $name,
            'description' => $normalizedDescription,
            'type' => $type,
            'is_protected' => false,
        ];

        if ($type === Account::TYPE_CREDIT) {
            if (! isset($creditMeta['credit_limit']) || $creditMeta['credit_limit'] === null) {
                throw new InvalidCreditLimit('Una cuenta de crédito requiere credit_limit.');
            }

            $closing = $creditMeta['closing_day'] ?? null;
            $payment = $creditMeta['payment_day'] ?? null;
            if (
                $closing !== null && $payment !== null
                && (int) $closing === (int) $payment
            ) {
                throw new InvalidCreditMetadata();
            }

            $attributes['credit_limit'] = $creditMeta['credit_limit'];
            $attributes['closing_day'] = $closing;
            $attributes['payment_day'] = $payment;
            $attributes['interest_rate'] = $creditMeta['interest_rate'] ?? null;
            $attributes['minimum_payment_pct'] = $creditMeta['minimum_payment_pct'] ?? null;
        }

        return Account::create($attributes);
    }
}
