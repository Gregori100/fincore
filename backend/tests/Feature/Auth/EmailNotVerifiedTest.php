<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class EmailNotVerifiedTest extends TestCase
{
    use RefreshDatabase;

    public function test_unverified_user_cannot_access_finance()
    {
        $user = User::factory()->unverified()->create();

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/finance/state')
            ->assertStatus(403); // middleware 'verified' rechaza con 403 en JSON
    }

    public function test_verified_user_can_access_finance()
    {
        $user = $this->createUserWithBolsa(); // verified by default

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/finance/state')
            ->assertOk();
    }
}
