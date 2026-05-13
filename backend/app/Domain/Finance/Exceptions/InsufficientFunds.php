<?php

namespace App\Domain\Finance\Exceptions;

class InsufficientFunds extends DomainException
{
    protected $message = 'Fondos insuficientes en la cuenta de origen.';

    public function errorCode(): string
    {
        return 'insufficient_funds';
    }
}
