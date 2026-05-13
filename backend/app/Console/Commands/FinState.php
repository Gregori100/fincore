<?php

namespace App\Console\Commands;

use App\Console\Commands\Concerns\ResolvesUser;
use App\Domain\Finance\Services\FinancialStateService;
use App\Models\Account;
use Illuminate\Console\Command;

class FinState extends Command
{
    use ResolvesUser;

    protected $signature = 'fin:state {--user= : Email del usuario}';

    protected $description = 'Muestra el estado financiero actual';

    public function handle(): int
    {
        try {
            $user = $this->resolveUser();
        } catch (\Exception $e) {
            $this->error($e->getMessage());
            return self::FAILURE;
        }

        $state = new FinancialStateService($user->id);

        $this->line("\n=== FINCORE STATE (user={$user->email}) ===\n");
        $this->info('BO: ' . number_format($state->getBO(), 2));
        $this->info('DE: ' . number_format($state->getDE(), 2));
        $this->info('CR: ' . number_format($state->getCR(), 2));

        $this->info("\nBurn rate mensual: " . number_format($state->getMonthlyBurnRate(), 2));
        $this->info('Uso de crédito: ' . $state->getCreditUsagePercentage() . '%');

        $this->line("\n--- Cuentas ---");
        $rows = $state->getAccounts()->map(function (Account $a) {
            return [
                $a->id,
                $a->name,
                $a->type,
                number_format($a->balance ?? 0, 2),
                $a->isCredit() && $a->credit_limit !== null
                    ? number_format($a->credit_limit, 2)
                    : '-',
                $a->isCredit() && isset($a->available_credit)
                    ? number_format($a->available_credit, 2)
                    : '-',
            ];
        })->toArray();

        $this->table(
            ['ID', 'Nombre', 'Tipo', 'Balance', 'Límite', 'Disp.'],
            $rows,
        );

        $this->line("\n--- Últimos movimientos ---");
        foreach ($state->getRecentEntries(10) as $entry) {
            $origin = $entry->origin?->name ?? '—';
            $dest = $entry->destination?->name ?? '—';
            $this->line("[{$entry->kind}] {$entry->amount}  {$origin} → {$dest}  {$entry->description}");
        }

        $this->line("\n=== END FINCORE STATE ===\n");
        return self::SUCCESS;
    }
}
