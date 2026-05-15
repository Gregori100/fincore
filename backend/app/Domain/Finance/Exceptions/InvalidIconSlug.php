<?php

namespace App\Domain\Finance\Exceptions;

class InvalidIconSlug extends DomainException
{
    protected $message = 'El icono seleccionado no está en el catálogo permitido.';

    public function errorCode(): string
    {
        return 'invalid_icon_slug';
    }
}
