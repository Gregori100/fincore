<?php

namespace App\Domain\Finance\Exceptions;

class DuplicateAccountName extends DomainException
{
    protected $message = 'Ya tienes una cuenta con ese nombre.';

    public function errorCode(): string
    {
        return 'duplicate_account_name';
    }
}
