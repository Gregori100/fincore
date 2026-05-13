<?php

namespace Tests;

use App\Models\Account;
use App\Models\User;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    /**
     * Crea un usuario con su Bolsa asociada (replicando lo que hace
     * el listener CreateUserBolsaAccount cuando alguien se registra).
     * Por default el usuario está verified.
     */
    protected function createUserWithBolsa(array $attrs = []): User
    {
        $user = User::factory()->create($attrs);
        Account::factory()->cash()->for($user)->create();
        return $user;
    }
}
