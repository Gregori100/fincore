<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Auth\Notifications\VerifyEmail;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\URL;
use Tests\TestCase;

class EmailVerificationTest extends TestCase
{
    use RefreshDatabase;

    public function test_signed_link_marks_user_as_verified()
    {
        $user = User::factory()->unverified()->create();

        $signed = URL::temporarySignedRoute(
            'verification.verify',
            now()->addMinutes(60),
            ['id' => $user->id, 'hash' => sha1($user->email)],
        );

        $this->get($signed)->assertRedirect();

        $this->assertNotNull($user->fresh()->email_verified_at);
    }

    public function test_invalid_hash_is_rejected()
    {
        $user = User::factory()->unverified()->create();

        $signed = URL::temporarySignedRoute(
            'verification.verify',
            now()->addMinutes(60),
            ['id' => $user->id, 'hash' => 'wrong-hash'],
        );

        $this->get($signed)->assertForbidden();
        $this->assertNull($user->fresh()->email_verified_at);
    }

    public function test_resend_verification_email()
    {
        Notification::fake();
        $user = User::factory()->unverified()->create();

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/auth/email/verification-notification')
            ->assertOk();

        Notification::assertSentTo($user, VerifyEmail::class);
    }

    public function test_resend_noop_when_already_verified()
    {
        Notification::fake();
        $user = User::factory()->create(); // verified by default

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/auth/email/verification-notification')
            ->assertOk();

        Notification::assertNothingSent();
    }
}
