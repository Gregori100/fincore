<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class JournalEntry extends Model
{
    /** @use HasFactory<\Database\Factories\JournalEntryFactory> */
    use HasFactory;

    public const KIND_INCOME = 'income';
    public const KIND_EXPENSE = 'expense';
    public const KIND_CREDIT_EXPENSE = 'credit_expense';
    public const KIND_DEBT_PAYMENT = 'debt_payment';
    public const KIND_TRANSFER = 'transfer';
    public const KIND_ADJUSTMENT = 'adjustment';

    protected $fillable = [
        'user_id',
        'kind',
        'amount',
        'account_origin_id',
        'account_destination_id',
        'description',
        'occurred_at',
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'occurred_at' => 'datetime',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Las relaciones con Account usan withTrashed() porque las pólizas son
     * append-only e históricas: deben seguir cargando origin/destination
     * aunque la cuenta haya sido archivada (soft-deleted). Sin esto, las
     * entries de cuentas archivadas mostrarían `origin: null` en /entries.
     */
    public function origin(): BelongsTo
    {
        return $this->belongsTo(Account::class, 'account_origin_id')->withTrashed();
    }

    public function destination(): BelongsTo
    {
        return $this->belongsTo(Account::class, 'account_destination_id')->withTrashed();
    }
}
