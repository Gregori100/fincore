<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Password;
use Tests\TestCase;

class PasswordResetTest extends TestCase
{
    use RefreshDatabase;

    public function test_forgot_endpoint_sends_reset_email()
    {
        Notification::fake();
        $user = User::factory()->create(['email' => 'diego@example.com']);

        $this->postJson('/api/auth/password/forgot', ['email' => 'diego@example.com'])
            ->assertOk();

        Notification::assertSentTo($user, ResetPassword::class);
    }

    public function test_reset_endpoint_changes_password_with_valid_token()
    {
        $user = User::factory()->create([
            'email' => 'diego@example.com',
            'password' => 'old_password',
        ]);

        $token = Password::createToken($user);

        $this->postJson('/api/auth/password/reset', [
            'token' => $token,
            'email' => 'diego@example.com',
            'password' => 'new_password',
            'password_confirmation' => 'new_password',
        ])->assertOk();

        $this->assertTrue(Hash::check('new_password', $user->fresh()->password));
    }

    public function test_reset_fails_with_invalid_token()
    {
        User::factory()->create(['email' => 'diego@example.com']);

        $this->postJson('/api/auth/password/reset', [
            'token' => 'invalid-token',
            'email' => 'diego@example.com',
            'password' => 'new_password',
            'password_confirmation' => 'new_password',
        ])->assertStatus(422);
    }
}
