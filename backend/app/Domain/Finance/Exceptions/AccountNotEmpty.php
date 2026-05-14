<?php

namespace App\Domain\Finance\Exceptions;

class AccountNotEmpty extends DomainException
{
    protected $message = 'La cuenta tiene saldo o deuda pendiente y no puede archivarse.';

    public function __construct(?string $message = null)
    {
        parent::__construct($message ?? $this->message);
    }

    public function errorCode(): string
    {
        return 'account_not_empty';
    }
}
