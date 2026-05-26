<?php

namespace Tests\Feature\Plan;

use App\Domain\Finance\Plan\Actions\BulkCreatePlannedEvents;
use App\Domain\Finance\Plan\Exceptions\InvalidRecurrence;
use App\Models\Account;
use App\Models\JournalEntry;
use App\Models\PlannedEvent;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

class BulkCreatePlannedEventsTest extends TestCase
{
    use RefreshDatabase;

    private function rows(string $bolsaId): array
    {
        return [
            [
                'kind' => JournalEntry::KIND_INCOME,
                'amount' => 5700,
                'account_destination_id' => $bolsaId,
                'recurrence_type' => PlannedEvent::RECURRENCE_WEEKLY,
                'recurrence_day' => 4,
                'start_date' => Carbon::today()->toDateString(),
            ],
            [
                'kind' => JournalEntry::KIND_EXPENSE,
                'amount' => 1200,
                'account_origin_id' => $bolsaId,
                'recurrence_type' => PlannedEvent::RECURRENCE_ONE_OFF,
                'start_date' => Carbon::today()->addDays(5)->toDateString(),
            ],
        ];
    }

    public function test_creates_all_rows_in_one_call(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        $result = BulkCreatePlannedEvents::execute($user->id, $this->rows($bolsa->id));

        $this->assertSame(2, $result['created']);
        $this->assertSame(2, PlannedEvent::where('user_id', $user->id)->count());
    }

    public function test_rolls_back_all_if_one_row_invalid(): void
    {
        $user = $this->createUserWithBolsa();
        $bolsa = $user->accounts()->where('type', Account::TYPE_CASH)->firstOrFail();

        $rows = $this->rows($bolsa->id);
        // Fila inválida: expense apuntando a cuenta destino (contrato tipo↔kind roto).
        $rows[] = [
            'kind' => JournalEntry::KIND_EXPENSE,
            'amount' => 100,
            'account_destination_id' => $bolsa->id, // expense no lleva destino
            'recurrence_type' => PlannedEvent::RECURRENCE_ONE_OFF,
            'start_date' => Carbon::today()->toDateString(),
        ];

        try {
            BulkCreatePlannedEvents::execute($user->id, $rows);
            $this->fail('Se esperaba InvalidRecurrence por la fila inválida.');
        } catch (InvalidRecurrence $e) {
            $this->assertStringContainsString('Fila 3', $e->getMessage());
        }

        // Atómico: ninguno se creó.
        $this->assertSame(0, PlannedEvent::where('user_id', $user->id)->count());
    }

    public function test_rejects_empty_rows(): void
    {
        $user = $this->createUserWithBolsa();
        $this->expectException(InvalidRecurrence::class);
        BulkCreatePlannedEvents::execute($user->id, []);
    }
}
