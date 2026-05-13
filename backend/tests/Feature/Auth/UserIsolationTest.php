<?php

namespace Tests\Feature\Auth;

use App\Domain\Finance\Actions\RegisterIncome;
use App\Models\Account;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class UserIsolationTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_b_cannot_see_user_a_accounts()
    {
        $userA = $this->createUserWithBolsa();
        $userB = $this->createUserWithBolsa();

        Account::factory()->debit()->for($userA)->create(['name' => 'A-Bank']);
        Account::factory()->debit()->for($userB)->create(['name' => 'B-Bank']);

        $response = $this->actingAs($userB, 'sanctum')
            ->getJson('/api/finance/accounts')
            ->assertOk();

        $names = collect($response->json('accounts'))->pluck('name')->all();
        $this->assertContains('B-Bank', $names);
        $this->assertNotContains('A-Bank', $names);
    }

    public function test_user_b_cannot_modify_user_a_account()
    {
        $userA = $this->createUserWithBolsa();
        $userB = $this->createUserWithBolsa();
        $accountA = Account::factory()->debit()->for($userA)->create();

        $this->actingAs($userB, 'sanctum')
            ->patchJson('/api/finance/accounts/' . $accountA->id, ['name' => 'Hijacked'])
            ->assertNotFound();

        $this->assertNotEquals('Hijacked', $accountA->fresh()->name);
    }

    public function test_user_b_cannot_register_income_to_user_a_account()
    {
        $userA = $this->createUserWithBolsa();
        $userB = $this->createUserWithBolsa();
        $accountA = $userA->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        $this->actingAs($userB, 'sanctum')
            ->postJson('/api/finance/income', [
                'account_id' => $accountA->id,
                'amount' => 1000,
            ])
            ->assertNotFound();
    }

    public function test_user_b_state_does_not_include_user_a_data()
    {
        $userA = $this->createUserWithBolsa();
        $userB = $this->createUserWithBolsa();

        $accountA = $userA->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();
        RegisterIncome::execute($userA->id, $accountA->id, 5000);

        $response = $this->actingAs($userB, 'sanctum')
            ->getJson('/api/finance/state')
            ->assertOk();

        $this->assertEquals(0, $response->json('bo'));
    }
}
