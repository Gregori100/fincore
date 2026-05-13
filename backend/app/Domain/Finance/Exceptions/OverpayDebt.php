<?php

namespace App\Domain\Finance\Exceptions;

class OverpayDebt extends DomainException
{
    protected $message = 'El pago excede el saldo de la deuda.';

    public function errorCode(): string
    {
        return 'overpay_debt';
    }
}
