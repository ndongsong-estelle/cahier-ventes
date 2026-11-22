<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory;

    protected $fillable = ['phone', 'shop_name', 'pin_hash', 'pin_is_temporary', 'phone_verified_at'];

    protected $hidden = ['pin_hash', 'notes', 'failed_pin_attempts', 'locked_until'];

    protected function casts(): array
    {
        return [
            'pin_is_temporary' => 'boolean',
            'phone_verified_at' => 'datetime',
            'locked_until' => 'datetime',
            'failed_pin_attempts' => 'integer',
        ];
    }

    public function devices(): HasMany
    {
        return $this->hasMany(Device::class);
    }

    public function getAuthPassword(): string
    {
        return $this->pin_hash;
    }

    public function isLocked(): bool
    {
        return $this->locked_until !== null && $this->locked_until->isFuture();
    }

    /** Ce que l'app reçoit : jamais le code, ni les notes d'Estha. */
    public function toApi(): array
    {
        return [
            'id' => $this->id,
            'phone' => $this->phone,
            'shop_name' => $this->shop_name,
            'phone_verified' => $this->phone_verified_at !== null,
        ];
    }
}
