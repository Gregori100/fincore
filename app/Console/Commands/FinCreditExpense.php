<?php

namespace App\Console\Commands;

use App\Domain\Finance\Actions\RegisterCreditExpense;
use Illuminate\Console\Command;

class FinCreditExpense extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'fin:credit-expense {debtId} {amount} {description?}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Registra un gasto con tarjeta';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $debtId = $this->argument('debtId');
        $amount = (float) $this->argument('amount');
        $description = $this->argument('description');

        RegisterCreditExpense::execute(
            $debtId,
            $amount,
            $description
        );

        $this->info("Credit expense registered: $amount");
    }
}
