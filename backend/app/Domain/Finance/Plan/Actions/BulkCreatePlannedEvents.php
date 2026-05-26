<?php

namespace App\Domain\Finance\Plan\Actions;

use App\Domain\Finance\Exceptions\DomainException;
use App\Domain\Finance\Plan\Exceptions\InvalidRecurrence;
use App\Models\PlannedEvent;
use Illuminate\Support\Facades\DB;

class BulkCreatePlannedEvents
{
    /**
     * Crea varios eventos planeados en una sola transacción atómica: o se crean
     * todos, o ninguno. Si una fila es inválida, se aborta con el índice (base 0)
     * de la fila culpable y su mensaje, para que el frontend la señale.
     *
     * El frontend valida en vivo, así que el rechazo del backend es la red de
     * defensa: rara vez se dispara si la UI hizo su trabajo.
     *
     * @param  array<int, array>  $rows
     * @return array{created: int, events: array<int, PlannedEvent>}
     */
    public static function execute(string $userId, array $rows): array
    {
        if (empty($rows)) {
            throw new InvalidRecurrence('No hay eventos para crear.');
        }

        return DB::transaction(function () use ($userId, $rows) {
            $events = [];
            foreach (array_values($rows) as $index => $row) {
                try {
                    $events[] = CreatePlannedEvent::execute($userId, $row);
                } catch (DomainException $e) {
                    // Re-lanzamos con el contexto de la fila para que el front la marque.
                    throw new InvalidRecurrence("Fila ".($index + 1).": ".$e->getMessage());
                }
            }

            return [
                'created' => count($events),
                'events' => $events,
            ];
        });
    }
}
