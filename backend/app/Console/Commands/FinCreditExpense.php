<?php

namespace App\Console\Commands;

use App\Console\Commands\Concerns\ResolvesUser;
use App\Domain\Finance\Actions\RegisterCreditExpense;
use Illuminate\Console\Command;

class FinCreditExpense extends Command
{
    use ResolvesUser;

    protected $signature = 'fin:credit-expense {accountId} {amount} {description?} {--user= : Email del usuario}';

    protected $description = 'Registra un cargo a una cuenta de crédito';

    public function handle(): int
    {
        try {
            $user = $this->resolveUser();

            RegisterCreditExpense::execute(
                $user->id,
                (int) $this->argument('accountId'),
                (float) $this->argument('amount'),
                $this->argument('description'),
            );

            $this->info("Cargo a crédito registrado: {$this->argument('amount')} (user={$user->email})");
            return self::SUCCESS;
        } catch (\Exception $e) {
            $this->error($e->getMessage());
            return self::FAILURE;
        }
    }
}
