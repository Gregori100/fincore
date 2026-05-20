<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\InvalidAccountType;
use App\Models\Account;
use App\Models\JournalEntry;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class RegisterTransfer
{
    public static function execute(
        string $userId,
        string $originAccountId,
        string $destinationAccountId,
        float $amount,
        ?string $description = null,
        ?string $occurredAt = null,
    ): JournalEntry {
        if ($originAccountId === $destinationAccountId) {
            throw new InvalidAccountType('La cuenta de origen y destino no pueden ser la misma.');
        }

        return DB::transaction(function () use ($userId, $originAccountId, $destinationAccountId, $amount, $description, $occurredAt) {
            // Bloqueamos en orden lexicográfico (strcmp) de id para evitar
            // deadlocks entre dos transferencias simultáneas que crucen las
            // mismas cuentas en direcciones opuestas. Con UUID el orden no es
            // numérico, pero strcmp basta porque solo necesitamos que sea
            // determinista en ambas transacciones.
            [$firstId, $secondId] = strcmp($originAccountId, $destinationAccountId) < 0
                ? [$originAccountId, $destinationAccountId]
                : [$destinationAccountId, $originAccountId];

            Account::where('id', $firstId)
                ->where('user_id', $userId)
                ->lockForUpdate()
                ->firstOrFail();
            Account::where('id', $secondId)
                ->where('user_id', $userId)
                ->lockForUpdate()
                ->firstOrFail();

            $origin = Account::where('id', $originAccountId)
                ->where('user_id', $userId)
                ->firstOrFail();
            $destination = Account::where('id', $destinationAccountId)
                ->where('user_id', $userId)
                ->firstOrFail();

            if (! $origin->isCashLike() || ! $destination->isCashLike()) {
                throw new InvalidAccountType('Las transferencias solo se permiten entre cuentas cash o debit. Usa pay-credit para pagar tarjetas.');
            }

            return JournalEntry::create([
                'user_id' => $userId,
                'kind' => JournalEntry::KIND_TRANSFER,
                'amount' => $amount,
                'account_origin_id' => $origin->id,
                'account_destination_id' => $destination->id,
                'description' => $description,
                'occurred_at' => $occurredAt !== null ? Carbon::parse($occurredAt) : now(),
            ]);
        });
    }
}
