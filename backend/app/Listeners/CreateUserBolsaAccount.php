<?php

namespace App\Listeners;

use App\Models\Account;
use Illuminate\Auth\Events\Registered;

class CreateUserBolsaAccount
{
    public function handle(Registered $event): void
    {
        Account::create([
            'user_id' => $event->user->id,
            'name' => Account::PROTECTED_CASH_NAME,
            'type' => Account::TYPE_CASH,
            'is_protected' => true,
        ]);
    }
}
