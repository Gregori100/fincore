<?php

namespace App\Console\Commands;

use App\Domain\Finance\Actions\CreateDebt;
use Illuminate\Console\Command;

class FinCreateCredit extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'fin:credit:create {name} {limit}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Crea una nueva tarjeta o crédito';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $name = $this->argument('name');
        $limit = (float) $this->argument('limit');

        $debt = CreateDebt::execute($name, $limit);

        $this->info("Credit created: {$debt->name} (limit: {$debt->credit_limit})");
    }
}
