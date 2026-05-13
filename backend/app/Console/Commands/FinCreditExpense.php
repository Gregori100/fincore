<?php

namespace App\Console\Commands;

use App\Domain\Finance\Actions\RegisterCreditExpense;
use Illuminate\Console\Command;

class FinCreditExpense extends Command
{
    protected $signature = 'fin:credit-expense {accountId} {amount} {description?}';

    protected $description = 'Registra un cargo a una cuenta de crédito';

    public function handle(): int
    {
        try {
            RegisterCreditExpense::execute(
                (int) $this->argument('accountId'),
                (float) $this->argument('amount'),
                $this->argument('description'),
            );

            $this->info("Cargo a crédito registrado: {$this->argument('amount')}");
            return self::SUCCESS;
        } catch (\Exception $e) {
            $this->error($e->getMessage());
            return self::FAILURE;
        }
    }
}
