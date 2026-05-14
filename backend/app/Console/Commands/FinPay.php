<?php

namespace App\Console\Commands;

use App\Console\Commands\Concerns\ResolvesUser;
use App\Domain\Finance\Actions\PayCreditAccount;
use Illuminate\Console\Command;

class FinPay extends Command
{
    use ResolvesUser;

    protected $signature = 'fin:pay {originId} {creditAccountId} {amount} {description?} {--user= : Email del usuario}';

    protected $description = 'Paga una cuenta de crédito desde una cuenta cash/debit';

    public function handle(): int
    {
        try {
            $user = $this->resolveUser();

            PayCreditAccount::execute(
                $user->id,
                (string) $this->argument('originId'),
                (string) $this->argument('creditAccountId'),
                (float) $this->argument('amount'),
                $this->argument('description'),
            );

            $this->info("Pago aplicado: {$this->argument('amount')} (user={$user->email})");
            return self::SUCCESS;
        } catch (\Exception $e) {
            $this->error($e->getMessage());
            return self::FAILURE;
        }
    }
}
