<?php

namespace App\Console\Commands;

use App\Domain\Finance\Actions\RegisterIncome;
use Illuminate\Console\Command;

class FinIncome extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'fin:income {amount} {description?}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Registra un ingreso';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $amount = (float) $this->argument('amount');
        $description = $this->argument('description');

        RegisterIncome::execute($amount, $description);

        $this->info("Ingreso registrado: $amount");
    }
}
