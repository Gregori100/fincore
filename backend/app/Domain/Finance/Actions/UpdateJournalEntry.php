<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\ImmutableJournalField;
use App\Domain\Finance\Exceptions\InvalidCategoryAppliesTo;
use App\Domain\Finance\Support\JournalKindContract;
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
        // respeten el contrato de tipo según el kind. La validación vive en
        // JournalKindContract para compartirse con el subdominio Plan.
        $touchOrigin = array_key_exists('account_origin_id', $update);
        $touchDestination = array_key_exists('account_destination_id', $update);
        if ($touchOrigin || $touchDestination) {
            $finalOriginId = $touchOrigin ? $update['account_origin_id'] : $entry->account_origin_id;
            $finalDestinationId = $touchDestination ? $update['account_destination_id'] : $entry->account_destination_id;

            JournalKindContract::validateAccountsForKind(
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
}
