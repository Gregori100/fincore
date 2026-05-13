<?php

namespace App\Providers;

use Illuminate\Auth\Notifications\ResetPassword;
use Illuminate\Support\Facades\URL;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        // El backend vive detrás del proxy de Vite (frontend → http://api → backend).
        // Las requests llegan con Host: api, así que url() y rutas firmadas
        // construyen links como http://api/... que el navegador no puede resolver.
        // Forzamos el root URL a APP_URL (típicamente http://localhost:<APP_PORT>)
        // para que los emails y signed URLs apunten al puerto público del host.
        if ($appUrl = config('app.url')) {
            URL::forceRootUrl($appUrl);
            if (str_starts_with($appUrl, 'https://')) {
                URL::forceScheme('https');
            }
        }

        // El link de reset apunta al frontend (no al backend) porque el form
        // de captura de nueva contraseña vive en la SPA.
        ResetPassword::createUrlUsing(function ($user, string $token) {
            $frontend = rtrim(config('app.frontend_url', 'http://localhost:5173'), '/');
            return $frontend.'/reset-password?token='.$token.'&email='.urlencode($user->email);
        });

        // La creación automática de la Bolsa al registrarse vive en
        // App\Listeners\CreateUserBolsaAccount. Laravel 11+ lo descubre solo
        // por convención (handle(Registered $event)). NO lo registres aquí
        // manualmente — duplicarías la suscripción y crearías dos Bolsas.
    }
}
