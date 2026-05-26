<?php

use App\Http\Controllers\Auth\EmailVerificationController;
use App\Http\Controllers\Auth\LoginController;
use App\Http\Controllers\Auth\LogoutController;
use App\Http\Controllers\Auth\MeController;
use App\Http\Controllers\Auth\PasswordResetController;
use App\Http\Controllers\Auth\RegisterController;
use App\Http\Controllers\FinanceController;
use App\Http\Controllers\PlanController;
use App\Http\Controllers\SettingsController;
use Illuminate\Support\Facades\Route;

// --- Auth (públicos, con rate limit donde corresponde) ---
Route::prefix('auth')->group(function () {
    Route::post('/register', RegisterController::class)->middleware('throttle:6,1');
    Route::post('/login', LoginController::class)->middleware('throttle:6,1');

    Route::post('/password/forgot', [PasswordResetController::class, 'forgot'])
        ->middleware('throttle:6,1')
        ->name('password.email');

    Route::post('/password/reset', [PasswordResetController::class, 'reset'])
        ->middleware('throttle:6,1')
        ->name('password.update');

    Route::get('/email/verify/{id}/{hash}', [EmailVerificationController::class, 'verify'])
        ->middleware('signed')
        ->name('verification.verify');

    // --- Auth (requieren sesión válida) ---
    Route::middleware('auth:sanctum')->group(function () {
        Route::get('/me', MeController::class);
        Route::post('/logout', [LogoutController::class, 'current']);
        Route::post('/logout-all', [LogoutController::class, 'all']);

        Route::post('/email/verification-notification', [EmailVerificationController::class, 'resend'])
            ->middleware('throttle:6,1')
            ->name('verification.send');
    });
});

// --- Finance (auth + email verified obligatorio) ---
Route::middleware(['auth:sanctum', 'verified'])->prefix('finance')->group(function () {
    Route::get('/state', [FinanceController::class, 'state']);
    Route::get('/entries', [FinanceController::class, 'listEntries']);
    Route::patch('/entries/{id}', [FinanceController::class, 'updateEntry']);
    Route::delete('/entries/{id}', [FinanceController::class, 'cancelEntry']);

    Route::get('/accounts', [FinanceController::class, 'listAccounts']);
    Route::post('/accounts', [FinanceController::class, 'createAccount']);
    Route::patch('/accounts/{id}', [FinanceController::class, 'updateAccount']);
    Route::delete('/accounts/{id}', [FinanceController::class, 'deleteAccount']);

    Route::get('/categories', [FinanceController::class, 'listCategories']);
    Route::post('/categories', [FinanceController::class, 'createCategory']);
    Route::patch('/categories/{id}', [FinanceController::class, 'updateCategory']);
    Route::delete('/categories/{id}', [FinanceController::class, 'archiveCategory']);

    Route::get('/reports/by-category', [FinanceController::class, 'reportByCategory']);
    Route::get('/reports/cashflow-monthly', [FinanceController::class, 'reportCashflowMonthly']);
    Route::get('/reports/month-comparison', [FinanceController::class, 'reportMonthComparison']);
    Route::get('/reports/credit-cards', [FinanceController::class, 'reportCreditCards']);
    Route::get('/reports/budgets', [FinanceController::class, 'reportBudgets']);

    Route::post('/income', [FinanceController::class, 'income']);
    Route::post('/expense', [FinanceController::class, 'expense']);
    Route::post('/credit-expense', [FinanceController::class, 'creditExpense']);
    Route::post('/pay-credit', [FinanceController::class, 'payCredit']);
    Route::post('/transfer', [FinanceController::class, 'transfer']);

    Route::get('/plan/events', [PlanController::class, 'listEvents']);
    Route::delete('/plan/events', [PlanController::class, 'clearEvents']);
    Route::post('/plan/events', [PlanController::class, 'createEvent']);
    Route::patch('/plan/events/{id}', [PlanController::class, 'updateEvent']);
    Route::delete('/plan/events/{id}', [PlanController::class, 'deleteEvent']);
    Route::post('/plan/events/{eventId}/overrides', [PlanController::class, 'createOverride']);
    Route::patch('/plan/overrides/{id}', [PlanController::class, 'updateOverride']);
    Route::delete('/plan/overrides/{id}', [PlanController::class, 'deleteOverride']);
    Route::get('/plan/projection', [PlanController::class, 'projection']);

    Route::post('/reset', [SettingsController::class, 'hardReset']);
});
