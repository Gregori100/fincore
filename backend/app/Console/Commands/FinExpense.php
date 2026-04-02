<?php

namespace App\Console\Commands;

use App\Domain\Finance\Actions\RegisterExpense;
use App\Domain\Finance\Exceptions\InsufficientFunds;
use Illuminate\Console\Command;

class FinExpense extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'fin:expense {amount} {description?}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Registra un gasto';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $amount = (float) $this->argument('amount');
        $description = $this->argument('description');

        try {
            RegisterExpense::execute($amount, $description);
            $this->info("Gasto registrado: $amount");
        } catch (InsufficientFunds $e) {
            $this->error($e->getMessage());
        }
    }
}
