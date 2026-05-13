<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Account extends Model
{
    /** @use HasFactory<\Database\Factories\AccountFactory> */
    use HasFactory;

    public const TYPE_CASH = 'cash';
    public const TYPE_DEBIT = 'debit';
    public const TYPE_CREDIT = 'credit';

    public const PROTECTED_CASH_NAME = 'Bolsa';

    protected $fillable = [
        'user_id',
        'name',
        'type',
        'is_protected',
        'credit_limit',
        'closing_day',
        'payment_day',
        'interest_rate',
        'minimum_payment_pct',
    ];

    protected $casts = [
        'is_protected' => 'bool',
        'credit_limit' => 'decimal:2',
        'closing_day' => 'integer',
        'payment_day' => 'integer',
        'interest_rate' => 'decimal:4',
        'minimum_payment_pct' => 'decimal:4',
    ];

    public function originatedEntries(): HasMany
    {
        return $this->hasMany(JournalEntry::class, 'account_origin_id');
    }

    public function destinedEntries(): HasMany
    {
        return $this->hasMany(JournalEntry::class, 'account_destination_id');
    }

    public function isCredit(): bool
    {
        return $this->type === self::TYPE_CREDIT;
    }

    public function isCashLike(): bool
    {
        return in_array($this->type, [self::TYPE_CASH, self::TYPE_DEBIT], true);
    }
}
