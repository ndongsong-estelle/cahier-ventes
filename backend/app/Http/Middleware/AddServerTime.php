<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/** Chaque réponse JSON de l'API contient server_time (correction d'horloge côté app). */
class AddServerTime
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);
        if ($response instanceof JsonResponse) {
            $data = $response->getData(true);
            if (is_array($data) && ($data === [] || ! array_is_list($data))) {
                $data['server_time'] = now()->toIso8601ZuluString();
                $response->setData($data);
            }
        }

        return $response;
    }
}
