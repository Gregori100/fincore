<?php

namespace App\Providers;

use App\Listeners\CreateUserBolsaAccount;
use Illuminate\Auth\Events\Registered;
use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        // El link de reset apunta al frontend (no al backend) porque el form
        // de captura de nueva contraseña vive en la SPA.
        ResetPassword::createUrlUsing(function ($user, string $token) {
            $frontend = rtrim(config('app.frontend_url', 'http://localhost:5173'), '/');
            return $frontend.'/reset-password?token='.$token.'&email='.urlencode($user->email);
        });

        // Crea automáticamente la cuenta Bolsa (cash, protegida) cuando se
        // registra un nuevo usuario.
        Event::listen(Registered::class, CreateUserBolsaAccount::class);
    }
}
