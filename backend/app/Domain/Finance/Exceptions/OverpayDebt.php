<?php

namespace App\Domain\Finance\Exceptions;

use Exception;

class OverpayDebt extends Exception
{
    protected $message = 'El pago excede el saldo de la deuda.';
}
