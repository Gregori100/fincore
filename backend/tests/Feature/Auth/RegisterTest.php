<?php

namespace Tests\Feature\Auth;

use App\Models\Account;
use App\Models\User;
use Illuminate\Auth\Notifications\VerifyEmail;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Tests\TestCase;

class RegisterTest extends TestCase
{
    use RefreshDatabase;

    public function test_register_creates_user_with_token_and_bolsa()
    {
        Notification::fake();

        $response = $this->postJson('/api/auth/register', [
            'name' => 'Diego',
            'email' => 'diego@example.com',
            'password' => 'secret1234',
            'password_confirmation' => 'secret1234',
        ]);

        $response->assertCreated()
            ->assertJsonStructure(['user' => ['id', 'name', 'email'], 'token']);

        $user = User::firstWhere('email', 'diego@example.com');
        $this->assertNotNull($user);

        // El listener crea la Bolsa automáticamente
        $bolsa = Account::where('user_id', $user->id)
            ->where('type', Account::TYPE_CASH)
            ->first();
        $this->assertNotNull($bolsa);
        $this->assertTrue((bool) $bolsa->is_protected);

        // Y envió email de verificación
        Notification::assertSentTo($user, VerifyEmail::class);
    }

    public function test_register_rejects_duplicate_email()
    {
        User::factory()->create(['email' => 'taken@example.com']);

        $this->postJson('/api/auth/register', [
            'name' => 'Otro',
            'email' => 'taken@example.com',
            'password' => 'secret1234',
            'password_confirmation' => 'secret1234',
        ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['email']);
    }

    public function test_register_requires_password_confirmation()
    {
        $this->postJson('/api/auth/register', [
            'name' => 'Diego',
            'email' => 'diego@example.com',
            'password' => 'secret1234',
        ])
            ->assertStatus(422)
            ->assertJsonValidationErrors(['password']);
    }
}
