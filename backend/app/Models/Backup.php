<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Backup extends Model
{
    use HasUuids;

    public const UPDATED_AT = null;

    protected $fillable = ['id', 'user_id', 'path', 'size_bytes', 'sha256', 'counts', 'encrypted'];

    protected function casts(): array
    {
        return [
            'counts' => 'array',
            'encrypted' => 'boolean',
            'size_bytes' => 'integer',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
