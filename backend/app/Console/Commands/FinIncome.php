<?php

namespace App\Console\Commands;

use App\Console\Commands\Concerns\ResolvesUser;
use App\Domain\Finance\Actions\RegisterIncome;
use Illuminate\Console\Command;

class FinIncome extends Command
{
    use ResolvesUser;

    protected $signature = 'fin:income {accountId} {amount} {description?} {--user= : Email del usuario}';

    protected $description = 'Registra un ingreso en una cuenta cash/debit';

    public function handle(): int
    {
        try {
            $user = $this->resolveUser();

            RegisterIncome::execute(
                $user->id,
                (int) $this->argument('accountId'),
                (float) $this->argument('amount'),
                $this->argument('description'),
            );

            $this->info("Ingreso registrado: {$this->argument('amount')} (user={$user->email})");
            return self::SUCCESS;
        } catch (\Exception $e) {
            $this->error($e->getMessage());
            return self::FAILURE;
        }
    }
}
