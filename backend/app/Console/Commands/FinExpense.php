<?php

namespace App\Console\Commands;

use App\Console\Commands\Concerns\ResolvesUser;
use App\Domain\Finance\Actions\RegisterExpense;
use Illuminate\Console\Command;

class FinExpense extends Command
{
    use ResolvesUser;

    protected $signature = 'fin:expense {accountId} {amount} {description?} {--user= : Email del usuario}';

    protected $description = 'Registra un gasto desde una cuenta cash/debit';

    public function handle(): int
    {
        try {
            $user = $this->resolveUser();

            RegisterExpense::execute(
                $user->id,
                (string) $this->argument('accountId'),
                (float) $this->argument('amount'),
                $this->argument('description'),
            );

            $this->info("Gasto registrado: {$this->argument('amount')} (user={$user->email})");
            return self::SUCCESS;
        } catch (\Exception $e) {
            $this->error($e->getMessage());
            return self::FAILURE;
        }
    }
}
