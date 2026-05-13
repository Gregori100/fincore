<?php

namespace App\Console\Commands\Concerns;

use App\Models\User;
use RuntimeException;

/**
 * Resuelve el usuario sobre el que opera un comando fin:*.
 *
 * - Si la opción --user=email viene, busca por email o falla.
 * - Si no viene y hay exactamente 1 usuario en BD, lo usa por conveniencia.
 * - Si no viene y hay 0 o >1, exige el flag con un mensaje claro.
 */
trait ResolvesUser
{
    protected function resolveUser(): User
    {
        $email = $this->option('user');

        if ($email) {
            $user = User::firstWhere('email', $email);
            if (! $user) {
                throw new RuntimeException("No existe un usuario con email '{$email}'.");
            }
            return $user;
        }

        $count = User::count();

        if ($count === 0) {
            throw new RuntimeException('No hay usuarios registrados. Registra uno primero con POST /api/auth/register.');
        }

        if ($count > 1) {
            throw new RuntimeException('Hay más de un usuario en el sistema. Pasa --user=email para especificar cuál.');
        }

        return User::first();
    }
}
