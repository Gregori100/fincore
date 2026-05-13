<?php

namespace App\Console\Commands;

use App\Console\Commands\Concerns\ResolvesUser;
use App\Domain\Finance\Actions\CreateAccount;
use App\Models\Account;
use Illuminate\Console\Command;

class FinCreateAccount extends Command
{
    use ResolvesUser;

    protected $signature = 'fin:account:create
        {name : Nombre de la cuenta}
        {type : debit | credit}
        {--limit= : Límite de crédito (solo credit)}
        {--closingDay= : Día del mes de corte (solo credit)}
        {--paymentDay= : Día del mes de pago (solo credit)}
        {--interest= : Tasa de interés mensual, ej. 0.0367}
        {--minPct= : Porcentaje de pago mínimo, ej. 0.05}
        {--user= : Email del usuario (opcional si solo hay uno)}';

    protected $description = 'Crea una cuenta de débito o crédito';

    public function handle(): int
    {
        try {
            $user = $this->resolveUser();

            $name = $this->argument('name');
            $type = $this->argument('type');

            $meta = [];
            if ($type === Account::TYPE_CREDIT) {
                $meta = array_filter([
                    'credit_limit' => $this->option('limit') !== null ? (float) $this->option('limit') : null,
                    'closing_day' => $this->option('closingDay') !== null ? (int) $this->option('closingDay') : null,
                    'payment_day' => $this->option('paymentDay') !== null ? (int) $this->option('paymentDay') : null,
                    'interest_rate' => $this->option('interest') !== null ? (float) $this->option('interest') : null,
                    'minimum_payment_pct' => $this->option('minPct') !== null ? (float) $this->option('minPct') : null,
                ], fn ($v) => $v !== null);
            }

            $account = CreateAccount::execute($user->id, $name, $type, $meta);

            $this->info("Cuenta creada [{$account->id}] {$account->name} (type={$account->type}, user={$user->email})");

            return self::SUCCESS;
        } catch (\Exception $e) {
            $this->error($e->getMessage());
            return self::FAILURE;
        }
    }
}
