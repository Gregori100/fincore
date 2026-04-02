<?php

namespace Tests\Feature\Finance;

use App\Domain\Finance\Actions\CreateDebt;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CreateCreditTest extends TestCase
{
    use RefreshDatabase;

    public function test_create_credit()
    {
        $debt = CreateDebt::execute("BBVA", 10000);

        $this->assertDatabaseHas('debts', [
            'name' => 'BBVA',
            'credit_limit' => 10000,
            'initial_amount' => 0,
            'current_amount' => 0
        ]);
    }
}
