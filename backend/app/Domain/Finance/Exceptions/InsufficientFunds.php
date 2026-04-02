<?php

namespace App\Domain\Finance\Exceptions;

use Exception;

class InsufficientFunds extends Exception
{
    protected $message = 'Fondos insuficientes en la bolsa (BO).';
}
