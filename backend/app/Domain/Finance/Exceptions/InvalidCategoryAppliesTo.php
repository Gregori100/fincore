<?php

namespace App\Domain\Finance\Exceptions;

class InvalidCategoryAppliesTo extends DomainException
{
    protected $message = 'Esta categoría no aplica al tipo de movimiento.';

    public function errorCode(): string
    {
        return 'invalid_category_applies_to';
    }
}
