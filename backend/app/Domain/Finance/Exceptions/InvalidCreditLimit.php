<?php

namespace App\Domain\Finance\Exceptions;

class InvalidCreditLimit extends DomainException
{
    protected $message = 'El nuevo límite no puede ser menor a la deuda actual de la tarjeta.';

    public function __construct(?string $message = null)
    {
        parent::__construct($message ?? $this->message);
    }

    public function errorCode(): string
    {
        return 'invalid_credit_limit';
    }
}
