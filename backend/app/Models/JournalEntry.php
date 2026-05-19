<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class JournalEntry extends Model
{
    /** @use HasFactory<\Database\Factories\JournalEntryFactory> */
    use HasFactory, HasUuids, SoftDeletes;

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
        'category_id',
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

    /**
     * No usamos withTrashed: si la categoría se archiva, el badge desaparece de
     * las tablas (el entry queda como "Sin categorizar" visualmente). El
     * category_id sigue persistido por si la categoría se reactiva en el futuro.
     */
    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    /**
     * Mapea el `kind` interno al "kind aplicable a categorías", que es lo que
     * el catálogo de Category entiende (`income` | `expense`). credit_expense
     * se categoriza con categorías de gasto. transfer / debt_payment / adjustment
     * no se categorizan: devuelve null.
     */
    public function categoryKind(): ?string
    {
        return match ($this->kind) {
            self::KIND_INCOME => Category::APPLIES_INCOME,
            self::KIND_EXPENSE, self::KIND_CREDIT_EXPENSE => Category::APPLIES_EXPENSE,
            default => null,
        };
    }
}
