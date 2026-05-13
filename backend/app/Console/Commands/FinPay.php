<?php

namespace App\Console\Commands;

use App\Domain\Finance\Actions\PayCreditAccount;
use Illuminate\Console\Command;

class FinPay extends Command
{
    protected $signature = 'fin:pay {originId} {creditAccountId} {amount} {description?}';

    protected $description = 'Paga una cuenta de crédito desde una cuenta cash/debit';

    public function handle(): int
    {
        try {
            PayCreditAccount::execute(
                (int) $this->argument('originId'),
                (int) $this->argument('creditAccountId'),
                (float) $this->argument('amount'),
                $this->argument('description'),
            );

            $this->info("Pago aplicado: {$this->argument('amount')}");
            return self::SUCCESS;
        } catch (\Exception $e) {
            $this->error($e->getMessage());
            return self::FAILURE;
        }
    }
}
