<?php

namespace App\Domain\Finance\Exceptions;

class DuplicateCategoryName extends DomainException
{
    protected $message = 'Ya tienes una categoría con ese nombre.';

    public function errorCode(): string
    {
        return 'duplicate_category_name';
    }
}
