<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class LoginTest extends TestCase
{
    use RefreshDatabase;

    public function test_login_with_valid_credentials_returns_token()
    {
        $user = User::factory()->create([
            'email' => 'diego@example.com',
            'password' => 'secret1234',
        ]);

        $this->postJson('/api/auth/login', [
            'email' => 'diego@example.com',
            'password' => 'secret1234',
        ])
            ->assertOk()
            ->assertJsonStructure(['user' => ['id', 'email'], 'token']);
    }

    public function test_login_rejects_invalid_password()
    {
        User::factory()->create([
            'email' => 'diego@example.com',
            'password' => 'secret1234',
        ]);

        $this->postJson('/api/auth/login', [
            'email' => 'diego@example.com',
            'password' => 'wrong',
        ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['email']);
    }

    public function test_login_rejects_unknown_email()
    {
        $this->postJson('/api/auth/login', [
            'email' => 'nobody@example.com',
            'password' => 'whatever',
        ])
            ->assertStatus(422);
    }
}
