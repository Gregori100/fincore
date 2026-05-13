<?php

namespace App\Domain\Finance\Exceptions;

class CreditLimitExceeded extends DomainException
{
    protected $message = 'Límite de crédito excedido.';

    public function errorCode(): string
    {
        return 'credit_limit_exceeded';
    }
}
