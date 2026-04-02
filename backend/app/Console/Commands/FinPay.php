<?php

namespace App\Console\Commands;

use App\Domain\Finance\Actions\PayDebt;
use Illuminate\Console\Command;

class FinPay extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'fin:pay {debtId} {amount} {description?}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Paga una deuda';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        try {
            PayDebt::execute(
                (int) $this->argument('debtId'),
                (float)$this->argument('amount'),
                $this->argument('description')
            );

            $this->info("Debt paid successfully");
        } catch (\Exception $e) {
            $this->error($e->getMessage());
        }
    }
}
