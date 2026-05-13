<?php

namespace Database\Seeders;

use App\Models\Account;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        Account::firstOrCreate(
            ['type' => Account::TYPE_CASH, 'user_id' => null],
            [
                'name' => Account::PROTECTED_CASH_NAME,
                'is_protected' => true,
            ]
        );
    }
}
