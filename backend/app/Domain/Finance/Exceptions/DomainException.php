<?php

namespace App\Domain\Finance\Exceptions;

use Exception;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

abstract class DomainException extends Exception
{
    protected int $httpStatus = 422;

    abstract public function errorCode(): string;

    public function render(Request $request): JsonResponse|false
    {
        if (! $request->expectsJson()) {
            return false;
        }

        return response()->json([
            'error' => $this->getMessage(),
            'code' => $this->errorCode(),
        ], $this->httpStatus);
    }
}
