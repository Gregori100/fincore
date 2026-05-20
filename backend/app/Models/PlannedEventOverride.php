<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PlannedEventOverride extends Model
{
    use HasFactory;
    use HasUuids;

    protected $fillable = [
        'planned_event_id',
        'occurrence_date',
        'amount',
        'is_skipped',
    ];

    protected $casts = [
        'occurrence_date' => 'date',
        'amount' => 'decimal:2',
        'is_skipped' => 'boolean',
    ];

    public function event(): BelongsTo
    {
        return $this->belongsTo(PlannedEvent::class, 'planned_event_id');
    }
}
