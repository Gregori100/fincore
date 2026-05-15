<?php

namespace App\Domain\Finance\Exceptions;

class InvalidColorSlug extends DomainException
{
    protected $message = 'El color seleccionado no está en la paleta permitida.';

    public function errorCode(): string
    {
        return 'invalid_color_slug';
    }
}
