<?php

use App\Http\Controllers\FinanceController;
use Illuminate\Support\Facades\Route;

Route::prefix('finance')->group(function () {
    Route::get('/state', [FinanceController::class, 'state']);

    Route::post('/income', [FinanceController::class, 'income']);
    Route::post('/expense', [FinanceController::class, 'expense']);
    Route::post('/pay-debt', [FinanceController::class, 'payDebt']);
});
