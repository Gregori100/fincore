<?php

namespace Tests\Feature\Auth;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class UnauthenticatedAccessTest extends TestCase
{
    use RefreshDatabase;

    public function test_finance_routes_require_authentication()
    {
        $endpoints = [
            ['GET', '/api/finance/state'],
            ['GET', '/api/finance/entries'],
            ['GET', '/api/finance/accounts'],
            ['POST', '/api/finance/accounts'],
            ['POST', '/api/finance/income'],
            ['POST', '/api/finance/expense'],
            ['POST', '/api/finance/credit-expense'],
            ['POST', '/api/finance/pay-credit'],
            ['POST', '/api/finance/transfer'],
        ];

        foreach ($endpoints as [$method, $path]) {
            $this->json($method, $path)
                ->assertUnauthorized();
        }
    }
}
