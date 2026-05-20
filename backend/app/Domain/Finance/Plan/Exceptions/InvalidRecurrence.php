<?php

namespace App\Domain\Finance\Plan\Exceptions;

use App\Domain\Finance\Exceptions\DomainException;

class InvalidRecurrence extends DomainException
{
    protected $message = 'Configuración de recurrencia inválida.';

    public function errorCode(): string
    {
        return 'invalid_recurrence';
    }
}
