<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;

class Category extends Model
{
    /** @use HasFactory<\Database\Factories\CategoryFactory> */
    use HasFactory, HasUuids, SoftDeletes;

    public const APPLIES_INCOME = 'income';
    public const APPLIES_EXPENSE = 'expense';
    public const APPLIES_BOTH = 'both';

    protected $fillable = [
        'user_id',
        'name',
        'applies_to',
        'color_slug',
        'icon_slug',
        'monthly_limit',
    ];

    protected $casts = [
        'monthly_limit' => 'decimal:2',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function journalEntries(): HasMany
    {
        return $this->hasMany(JournalEntry::class);
    }

    /**
     * Filtra categorías compatibles con un kind de movimiento.
     * 'both' siempre aplica; el resto matchea su kind específico.
     */
    public function scopeForKind(Builder $query, string $kind): Builder
    {
        return $query->whereIn('applies_to', [$kind, self::APPLIES_BOTH]);
    }

    public function appliesToKind(string $kind): bool
    {
        return $this->applies_to === self::APPLIES_BOTH || $this->applies_to === $kind;
    }
}
