<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class LogoutTest extends TestCase
{
    use RefreshDatabase;

    public function test_logout_revokes_current_token()
    {
        $user = User::factory()->create();
        $token = $user->createToken('test')->plainTextToken;

        $this->assertEquals(1, $user->tokens()->count());

        $this->withHeader('Authorization', 'Bearer ' . $token)
            ->postJson('/api/auth/logout')
            ->assertOk();

        $this->assertEquals(0, $user->tokens()->count());
    }

    public function test_logout_all_revokes_every_token()
    {
        $user = User::factory()->create();
        $token1 = $user->createToken('mobile')->plainTextToken;
        $user->createToken('web');

        $this->assertEquals(2, $user->tokens()->count());

        $this->withHeader('Authorization', 'Bearer ' . $token1)
            ->postJson('/api/auth/logout-all')
            ->assertOk();

        $this->assertEquals(0, $user->tokens()->count());
    }

    public function test_me_returns_authenticated_user()
    {
        $user = User::factory()->create(['email' => 'who@example.com']);

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/auth/me')
            ->assertOk()
            ->assertJsonPath('user.email', 'who@example.com');
    }

    public function test_me_requires_auth()
    {
        $this->getJson('/api/auth/me')->assertUnauthorized();
    }
}
