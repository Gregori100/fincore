<?php

namespace App\Domain\Finance\Exceptions;

class InvalidAccountType extends DomainException
{
    protected $message = 'El tipo de cuenta no es válido para esta operación.';

    public function errorCode(): string
    {
        return 'invalid_account_type';
    }
}
