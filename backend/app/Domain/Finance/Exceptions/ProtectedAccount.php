<?php

namespace App\Domain\Finance\Exceptions;

class ProtectedAccount extends DomainException
{
    protected int $httpStatus = 409;

    protected $message = 'La cuenta está protegida y no puede modificarse ni eliminarse.';

    public function errorCode(): string
    {
        return 'protected_account';
    }
}
