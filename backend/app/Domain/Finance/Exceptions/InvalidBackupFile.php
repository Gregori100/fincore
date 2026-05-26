<?php

namespace App\Domain\Finance\Exceptions;

class InvalidBackupFile extends DomainException
{
    protected $message = 'El archivo de respaldo es inválido o incompatible.';

    public function errorCode(): string
    {
        return 'invalid_backup_file';
    }
}
