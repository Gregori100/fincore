<?php

namespace App\Console\Commands;

use App\Domain\Finance\Actions\RegisterExpense;
use Illuminate\Console\Command;

class FinExpense extends Command
{
    protected $signature = 'fin:expense {accountId} {amount} {description?}';

    protected $description = 'Registra un gasto desde una cuenta cash/debit';

    public function handle(): int
    {
        try {
            RegisterExpense::execute(
                (int) $this->argument('accountId'),
                (float) $this->argument('amount'),
                $this->argument('description'),
            );

            $this->info("Gasto registrado: {$this->argument('amount')}");
            return self::SUCCESS;
        } catch (\Exception $e) {
            $this->error($e->getMessage());
            return self::FAILURE;
        }
    }
}
