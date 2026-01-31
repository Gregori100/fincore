<?php

namespace App\Console\Commands;

use App\Domain\Finance\Services\FinancialStateService;
use Illuminate\Console\Command;

class FinState extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'fin:state';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Muestra el estado financiero actual';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $state = new FinancialStateService();

        $this->line("\n=== FINCORE STATE ===\n");

        $this->info("BO: " . $state->getBO());
        $this->info("DE: " . $state->getDE());
        $this->info("CR: " . $state->getCR());


        $this->info("\nBurn rate mensual: " . $state->getMonthlyBurnRate());
        $this->info("Uso de crédito: " . $state->getCreditUsagePercentage() . "%\n");

        $this->line("\n--- Deudas ---");
        foreach ($state->getDebts() as $debt) {
            $this->line("[{$debt->id}] {$debt->name} → {$debt->current_amount} / {$debt->credit_limit}");
        }

        $this->line("\n--- Últimos movimientos ---");
        foreach ($state->getMovements()->take(10) as $m) {
            $this->line("{$m->type}  {$m->amount}  {$m->description}");
        }

        $this->line("\n=== END FINCORE STATE ===\n");
    }
}
