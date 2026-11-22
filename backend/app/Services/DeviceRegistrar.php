<?php

namespace App\Services;

use App\Models\Device;
use App\Models\User;

class DeviceRegistrar
{
    public static function rules(): array
    {
        return [
            'device' => 'required|array',
            'device.id' => 'required|uuid',
            'device.app_version' => 'nullable|string|max:30',
            'device.android_version' => 'nullable|string|max:30',
            'device.model' => 'nullable|string|max:100',
        ];
    }

    /** Enregistre le téléphone et ouvre une session : les autres sessions sont fermées. */
    public static function login(User $user, array $device): string
    {
        $now = now();
        $row = Device::find($device['id']) ?? new Device(['id' => $device['id'], 'first_seen_at' => $now]);
        $row->fill([
            'user_id' => $user->id,
            'app_version' => $device['app_version'] ?? null,
            'android_version' => $device['android_version'] ?? null,
            'device_model' => $device['model'] ?? null,
            'last_seen_at' => $now,
        ])->save();

        $user->tokens()->delete();

        return $user->createToken($device['id'])->plainTextToken;
    }
}
