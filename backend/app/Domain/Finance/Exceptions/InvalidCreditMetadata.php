<?php

namespace App\Domain\Finance\Exceptions;

class InvalidCreditMetadata extends DomainException
{
    protected $message = 'El día de corte y pago no pueden ser iguales.';

    public function __construct(?string $message = null)
    {
        parent::__construct($message ?? $this->message);
    }

    public function errorCode(): string
    {
        return 'invalid_credit_metadata';
    }
}
