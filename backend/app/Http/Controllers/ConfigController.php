<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;

class ConfigController extends Controller
{
    public function show(): JsonResponse
    {
        return response()->json([
            'questions' => [],
            'backup_enabled' => (bool) config('pilote.backup.enabled'),
            'backup_min_interval_minutes' => (int) config('pilote.backup.min_interval_minutes'),
            'support_whatsapp' => config('pilote.support_whatsapp'),
        ]);
    }
}
