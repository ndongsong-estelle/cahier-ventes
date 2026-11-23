<?php

namespace App\Http\Controllers;

use App\Models\Question;
use Illuminate\Http\JsonResponse;

class ConfigController extends Controller
{
    public function show(): JsonResponse
    {
        return response()->json([
            'questions' => Question::where('active', true)->orderBy('after_days')->get()->map->toApi(),
            'backup_enabled' => (bool) config('pilote.backup.enabled'),
            'backup_min_interval_minutes' => (int) config('pilote.backup.min_interval_minutes'),
            'support_whatsapp' => config('pilote.support_whatsapp'),
        ]);
    }
}
