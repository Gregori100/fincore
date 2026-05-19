<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\ImmutableJournalField;
use App\Domain\Finance\Exceptions\InvalidAccountType;
use App\Domain\Finance\Exceptions\InvalidCategoryAppliesTo;
use App\Models\Account;
use App\Models\Category;
use App\Models\JournalEntry;
use Illuminate\Support\Carbon;

class UpdateJournalEntry
{
    /**
     * Campos editables retroactivamente. Sólo el `kind` queda fijo: cambiar la
     * naturaleza de un movimiento (ej. expense → transfer) es conceptualmente
     * otro registro. El resto se puede mover libre — la app es una libreta,
     * no un libro contable bloqueante: si una corrección deja saldo negativo
     * lo marcamos visualmente y seguimos.
     */
    private const EDITABLE_FIELDS = [
        'category_id',
        'description',
        'occurred_at',
        'account_origin_id',
        'account_destination_id',
        'amount',
    ];

    private const MAX_DESCRIPTION_LENGTH = 200;

    public static function execute(string $userId, string $entryId, array $changes): JournalEntry
    {
        // Si llega cualquier campo no editable, rechazamos sin tocar nada.
        $rejected = array_diff(array_keys($changes), self::EDITABLE_FIELDS);
        if (! empty($rejected)) {
            throw new ImmutableJournalField(
                'No se puede modificar: '.implode(', ', $rejected),
            );
        }

        $entry = JournalEntry::where('id', $entryId)
            ->where('user_id', $userId)
            ->firstOrFail();

        $update = array_intersect_key($changes, array_flip(self::EDITABLE_FIELDS));

        // Validar y normalizar category_id si vino en el update.
        if (array_key_exists('category_id', $update)) {
            if ($update['category_id'] === null) {
                // Permitido: limpia la categoría del entry.
            } else {
                $categoryKind = $entry->categoryKind();
                // transfer, debt_payment y adjustment no se categorizan.
                if ($categoryKind === null) {
                    throw new InvalidCategoryAppliesTo();
                }
                $category = Category::where('id', $update['category_id'])
                    ->where('user_id', $userId)
                    ->first();
                if (! $category) {
                    throw new InvalidCategoryAppliesTo('La categoría no existe o no te pertenece.');
                }
                if (! $category->appliesToKind($categoryKind)) {
                    throw new InvalidCategoryAppliesTo();
                }
            }
        }

        // Normalizar y validar amount. Único invariante duro: amount > 0
        // (registrar negativos cambiaría el sentido del kind).
        if (array_key_exists('amount', $update)) {
            $amount = $update['amount'];
            if (! is_numeric($amount) || (float) $amount <= 0) {
                throw new ImmutableJournalField('El monto debe ser mayor a 0.');
            }
            $update['amount'] = (float) $amount;
        }

        // Normalizar occurred_at: aceptamos ISO 8601 / Y-m-d y lo guardamos como
        // datetime. Sin restricción de pasado/futuro — la app es libreta libre.
        if (array_key_exists('occurred_at', $update)) {
            if ($update['occurred_at'] === null || $update['occurred_at'] === '') {
                throw new ImmutableJournalField('La fecha del movimiento no puede vaciarse.');
            }
            try {
                $update['occurred_at'] = Carbon::parse($update['occurred_at']);
            } catch (\Exception $e) {
                throw new ImmutableJournalField('Fecha inválida.');
            }
        }

        // Re-asignación de cuentas. Resolvemos los IDs finales (los que vinieron
        // en el update + los que se conservan del entry actual) y validamos que
        // respeten el contrato de tipo según el kind. No validamos fondos: si
        // una reasignación deja saldo negativo el frontend lo marca con badge.
        $touchOrigin = array_key_exists('account_origin_id', $update);
        $touchDestination = array_key_exists('account_destination_id', $update);
        if ($touchOrigin || $touchDestination) {
            $finalOriginId = $touchOrigin ? $update['account_origin_id'] : $entry->account_origin_id;
            $finalDestinationId = $touchDestination ? $update['account_destination_id'] : $entry->account_destination_id;

            self::validateAccountsForKind(
                $userId,
                $entry->kind,
                $finalOriginId,
                $finalDestinationId,
            );
        }

        // Normalizar description (igual patrón que UpdateAccount).
        if (array_key_exists('description', $update)) {
            if ($update['description'] === null) {
                $update['description'] = null;
            } else {
                $trimmed = trim((string) $update['description']);
                if (mb_strlen($trimmed) > self::MAX_DESCRIPTION_LENGTH) {
                    throw new ImmutableJournalField('La descripción no puede exceder '.self::MAX_DESCRIPTION_LENGTH.' caracteres.');
                }
                $update['description'] = $trimmed !== '' ? $trimmed : null;
            }
        }

        $entry->update($update);

        return $entry->fresh(['origin', 'destination', 'category']);
    }

    /**
     * Valida que la nueva combinación (origin, destination) sea coherente con el
     * kind del entry. Reusa las reglas que cada Action de registro aplica al crear.
     * Cuentas archivadas no son seleccionables (Account usa SoftDeletes y la query
     * default las oculta).
     */
    private static function validateAccountsForKind(
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
                throw new InvalidAccountType('Kind no soportado para reasignación de cuentas.');
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
