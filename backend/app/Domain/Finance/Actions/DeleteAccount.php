<?php

namespace App\Domain\Finance\Actions;

use App\Domain\Finance\Exceptions\ProtectedAccount;
use App\Models\Account;
use App\Models\JournalEntry;
use Illuminate\Support\Facades\DB;

class DeleteAccount
{
    public static function execute(int $userId, int $accountId): void
    {
        $account = Account::where('id', $accountId)
            ->where('user_id', $userId)
            ->firstOrFail();

        if ($account->is_protected) {
            throw new ProtectedAccount();
        }

        $hasEntries = JournalEntry::where('user_id', $userId)
            ->where(function ($q) use ($accountId) {
                $q->where('account_origin_id', $accountId)
                    ->orWhere('account_destination_id', $accountId);
            })
            ->exists();

        if ($hasEntries) {
            throw new ProtectedAccount('La cuenta tiene pólizas asociadas y no puede eliminarse.');
        }

        DB::transaction(fn () => $account->delete());
    }
}
