<?php

namespace App\Domain\Finance\Plan\Exceptions;

use App\Domain\Finance\Exceptions\DomainException;

class OverrideOnNonOccurrence extends DomainException
{
    protected $message = 'La fecha del override no corresponde a una ocurrencia válida.';

    public function errorCode(): string
    {
        return 'override_on_non_occurrence';
    }
}
