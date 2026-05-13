<?php

use App\Http\Controllers\FinanceController;
use Illuminate\Support\Facades\Route;

Route::prefix('finance')->group(function () {
    Route::get('/state', [FinanceController::class, 'state']);

    Route::get('/entries', [FinanceController::class, 'listEntries']);

    Route::get('/accounts', [FinanceController::class, 'listAccounts']);
    Route::post('/accounts', [FinanceController::class, 'createAccount']);
    Route::patch('/accounts/{id}', [FinanceController::class, 'updateAccount']);
    Route::delete('/accounts/{id}', [FinanceController::class, 'deleteAccount']);

    Route::post('/income', [FinanceController::class, 'income']);
    Route::post('/expense', [FinanceController::class, 'expense']);
    Route::post('/credit-expense', [FinanceController::class, 'creditExpense']);
    Route::post('/pay-credit', [FinanceController::class, 'payCredit']);
    Route::post('/transfer', [FinanceController::class, 'transfer']);
});
