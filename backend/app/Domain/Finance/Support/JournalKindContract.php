<?php

namespace App\Domain\Finance\Support;

use App\Domain\Finance\Exceptions\InvalidAccountType;
use App\Models\Account;
use App\Models\JournalEntry;

/**
 * Reglas tipo↔kind compartidas entre los movimientos reales (`UpdateJournalEntry`)
 * y los eventos planeados del subdominio Plan. Centralizar evita que las dos
 * familias diverjan en la interpretación de qué cuentas son válidas para cada kind.
 */
class JournalKindContract
{
    /**
     * Verifica que la combinación (origin, destination) respete el contrato del
     * kind. Resuelve cada id contra `accounts` filtrando por `user_id` (las
     * archivadas no se encuentran porque `Account` usa SoftDeletes y la query
     * por defecto las oculta).
     */
    public static function validateAccountsForKind(
        string $userId,
        string $kind,
        ?string $originId,
        ?string $destinationId,
    ): void {
        $origin = self::resolveAccount($userId, $originId);
        $destination = self::resolveAccount($userId, $destinationId);

        switch ($kind) {
            case JournalEntry::KIND_INCOME:
                if ($origin !== null) {
                    throw new InvalidAccountType('Un ingreso no tiene cuenta origen.');
                }
                if ($destination === null || ! $destination->isCashLike()) {
                    throw new InvalidAccountType('Un ingreso solo puede entrar en una cuenta cash o débito.');
                }
                break;

            case JournalEntry::KIND_EXPENSE:
                if ($destination !== null) {
                    throw new InvalidAccountType('Un gasto en efectivo/débito no tiene cuenta destino.');
                }
                if ($origin === null || ! $origin->isCashLike()) {
                    throw new InvalidAccountType('Un gasto debe salir de una cuenta cash o débito.');
                }
                break;

            case JournalEntry::KIND_CREDIT_EXPENSE:
                if ($destination !== null) {
                    throw new InvalidAccountType('Un cargo a tarjeta no tiene cuenta destino.');
                }
                if ($origin === null || ! $origin->isCredit()) {
                    throw new InvalidAccountType('Un cargo a tarjeta debe salir de una cuenta de crédito.');
                }
                break;

            case JournalEntry::KIND_TRANSFER:
                if ($origin === null || ! $origin->isCashLike() || $destination === null || ! $destination->isCashLike()) {
                    throw new InvalidAccountType('Las transferencias solo se permiten entre cuentas cash o débito.');
                }
                if ($origin->id === $destination->id) {
                    throw new InvalidAccountType('La cuenta de origen y destino no pueden ser la misma.');
                }
                break;

            case JournalEntry::KIND_DEBT_PAYMENT:
                if ($origin === null || ! $origin->isCashLike()) {
                    throw new InvalidAccountType('El pago debe salir de una cuenta cash o débito.');
                }
                if ($destination === null || ! $destination->isCredit()) {
                    throw new InvalidAccountType('El destino del pago debe ser una cuenta de crédito.');
                }
                break;

            default:
                throw new InvalidAccountType('Kind no soportado para validación tipo↔cuenta.');
        }
    }

    private static function resolveAccount(string $userId, ?string $accountId): ?Account
    {
        if ($accountId === null) {
            return null;
        }
        $account = Account::where('id', $accountId)
            ->where('user_id', $userId)
            ->first();
        if (! $account) {
            throw new InvalidAccountType('La cuenta seleccionada no existe o no te pertenece.');
        }

        return $account;
    }
}
