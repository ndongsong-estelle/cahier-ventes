<?php

use App\Models\User;
use App\Services\DeviceRegistrar;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

pest()->extend(TestCase::class)->use(RefreshDatabase::class)->in('Feature');

function device(?string $id = null): array
{
    return ['id' => $id ?? (string) Str::uuid(), 'app_version' => '1.0.0', 'android_version' => '13', 'model' => 'Tecno Spark'];
}

/** Crée un compte et renvoie [user, token]. */
function account(?string $deviceId = null): array
{
    $user = User::factory()->create();
    $token = DeviceRegistrar::login($user, device($deviceId));

    return [$user, $token];
}
