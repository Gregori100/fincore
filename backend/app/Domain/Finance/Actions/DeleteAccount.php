<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\ProtectedAccount;
use App\Models\Account;
use App\Models\JournalEntry;
use Illuminate\Support\Facades\DB;

class DeleteAccount
{
    public static function execute(int $accountId): void
    {
        $account = Account::findOrFail($accountId);

        if ($account->is_protected) {
            throw new ProtectedAccount();
        }

        $hasEntries = JournalEntry::where('account_origin_id', $accountId)
            ->orWhere('account_destination_id', $accountId)
            ->exists();

        if ($hasEntries) {
            throw new ProtectedAccount('La cuenta tiene pólizas asociadas y no puede eliminarse.');
        }

        DB::transaction(fn () => $account->delete());
    }
}
