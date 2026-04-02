<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Debt extends Model
{
    /** @use HasFactory<\Database\Factories\DebtFactory> */
    use HasFactory;
    protected $fillable = [
        'name',
        'initial_amount',
        'current_amount',
        'credit_limit',
    ];

    public function movements(): HasMany
    {
        return $this->hasMany(Movement::class);
    }
}
