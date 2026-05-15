<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\ImmutableJournalField;
use App\Domain\Finance\Exceptions\InvalidCategoryAppliesTo;
use App\Models\Category;
use App\Models\JournalEntry;

class UpdateJournalEntry
{
    /**
     * Solo se permiten editar `category_id` y `description`. El monto, las
     * cuentas, el kind y la fecha del movimiento son inmutables — la pieza
     * contable no debe cambiar después de registrarse.
     */
    private const EDITABLE_FIELDS = ['category_id', 'description'];

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
                $category = Category::where('id', $update['category_id'])
                    ->where('user_id', $userId)
                    ->first();
                if (! $category) {
                    throw new InvalidCategoryAppliesTo('La categoría no existe o no te pertenece.');
                }
                if (! $category->appliesToKind($entry->kind)) {
                    throw new InvalidCategoryAppliesTo();
                }
            }
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
