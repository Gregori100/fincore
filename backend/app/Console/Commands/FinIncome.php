<?php

namespace App\Console\Commands;

use App\Domain\Finance\Actions\RegisterIncome;
use Illuminate\Console\Command;

class FinIncome extends Command
{
    protected $signature = 'fin:income {accountId} {amount} {description?}';

    protected $description = 'Registra un ingreso en una cuenta cash/debit';

    public function handle(): int
    {
        try {
            RegisterIncome::execute(
                (int) $this->argument('accountId'),
                (float) $this->argument('amount'),
                $this->argument('description'),
            );

            $this->info("Ingreso registrado: {$this->argument('amount')}");
            return self::SUCCESS;
        } catch (\Exception $e) {
            $this->error($e->getMessage());
            return self::FAILURE;
        }
    }
}
