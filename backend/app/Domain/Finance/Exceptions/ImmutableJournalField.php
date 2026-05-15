<?php

namespace App\Domain\Finance\Exceptions;

class ImmutableJournalField extends DomainException
{
    protected $message = 'Solo se pueden editar la categoría y la descripción de un movimiento.';

    public function errorCode(): string
    {
        return 'immutable_journal_field';
    }
}
