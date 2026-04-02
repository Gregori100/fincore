<?php

namespace App\Domain\Finance\Exceptions;

use Exception;

class CreditLimitExceeded extends Exception
{
    protected $message = 'Límite de crédito excedido.';
}
