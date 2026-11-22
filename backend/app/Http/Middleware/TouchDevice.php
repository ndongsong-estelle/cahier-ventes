<?php

namespace App\Http\Middleware;

use App\Models\Device;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/** Met à jour devices.last_seen_at (le nom du token est l'id du téléphone). */
class TouchDevice
{
    public function handle(Request $request, Closure $next): Response
    {
        $token = $request->user()?->currentAccessToken();
        if ($token && isset($token->name)) {
            Device::whereKey($token->name)
                ->where('user_id', $request->user()->id)
                ->where('last_seen_at', '<', now()->subMinute())
                ->update(['last_seen_at' => now()]);
        }

        return $next($request);
    }
}
